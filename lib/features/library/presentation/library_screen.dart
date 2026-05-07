import "dart:async";
import "dart:typed_data";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:video_player/video_player.dart";

import "../../../app/app_state.dart";
import "../../../core/network/api_client.dart";
import "../data/library_repository.dart";

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.currentUserId,
    required this.items,
    required this.usingDemoItems,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.searchQuery,
    required this.typeFilter,
    required this.onApplyFilters,
    required this.onAddItem,
    required this.availableGenres,
    required this.onLoadLinks,
    required this.onLoadItemById,
    required this.onUpdateItem,
    required this.onAddFormatToWork,
    required this.onBeginPlaybackSession,
    required this.onPlaybackProgressChanged,
    required this.onPausePlaybackSession,
    required this.onCompletePlaybackSession,
    required this.onFlushPlaybackSession,
    required this.onEndPlaybackSession,
    required this.playbackSpeed,
    required this.onSetPlaybackSpeed,
    required this.pendingPlaybackSync,
    required this.playbackError,
    required this.onLoadBookContent,
    required this.onMarkItemViewed,
    required this.onOpenSearchTab,
    super.key,
  });

  final String? currentUserId;
  final List<MediaListItem> items;
  final bool usingDemoItems;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final String searchQuery;
  final String? typeFilter;
  final Future<void> Function(String searchQuery, String? typeFilter)
  onApplyFilters;
  final Future<void> Function({
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    MediaUploadPayload? uploadPayload,
  })
  onAddItem;
  final List<String> availableGenres;
  final Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks;
  final Future<MediaListItem?> Function(String mediaItemId) onLoadItemById;
  final Future<MediaListItem> Function({
    required String mediaItemId,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    MediaUploadPayload? uploadPayload,
    String? description,
  })
  onUpdateItem;
  final Future<MediaListItem> Function({
    required String sourceMediaItemId,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    String? description,
    MediaUploadPayload? uploadPayload,
  })
  onAddFormatToWork;
  final Future<PlaybackSessionConfig?> Function(MediaListItem item)
  onBeginPlaybackSession;
  final void Function({
    required int positionSeconds,
    required int? durationSeconds,
    required bool isPlaying,
    bool isCompleted,
  })
  onPlaybackProgressChanged;
  final Future<void> Function() onPausePlaybackSession;
  final Future<void> Function() onCompletePlaybackSession;
  final Future<void> Function() onFlushPlaybackSession;
  final void Function() onEndPlaybackSession;
  final double playbackSpeed;
  final void Function(double) onSetPlaybackSpeed;
  final bool pendingPlaybackSync;
  final String? playbackError;
  final Future<String> Function(MediaListItem item) onLoadBookContent;
  final void Function(String mediaItemId) onMarkItemViewed;
  final VoidCallback onOpenSearchTab;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  List<_WorkGroup> _buildWorkGroups(List<MediaListItem> items) {
    final groups = <String, List<MediaListItem>>{};
    for (final item in items) {
      final key =
          "${item.title.trim().toLowerCase()}::${(item.author ?? "").trim().toLowerCase()}";
      groups.putIfAbsent(key, () => <MediaListItem>[]).add(item);
    }
    final result = groups.values
        .map((groupItems) => _WorkGroup(groupItems: groupItems))
        .toList(growable: false);
    result.sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
    return result;
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    String selectedType = "book";
    String? selectedFileName;
    String? selectedFileMime;
    List<int>? selectedFileBytes;
    String? selectedCoverFileName;
    List<int>? selectedCoverFileBytes;
    String? selectedCoverFileMime;
    List<String> selectedGenres = [];
    String? genrePickerValue;
    String? submitError;
    bool isSubmitting = false;
    final genreOptions = _uniqueGenres(widget.availableGenres);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              setDialogState(() {
                isSubmitting = true;
                submitError = null;
              });
              try {
                if (selectedFileName != null &&
                    !_isFileCompatibleWithType(
                      filename: selectedFileName,
                      mimeType: selectedFileMime,
                      mediaType: selectedType,
                    )) {
                  setDialogState(() {
                    submitError =
                        "Выбранный файл не подходит для типа $selectedType";
                    isSubmitting = false;
                  });
                  return;
                }
                final requiresUpload =
                    selectedType == "audiobook" || selectedType == "video";
                if (requiresUpload &&
                    (selectedFileBytes == null || selectedFileName == null)) {
                  setDialogState(() {
                    submitError = "Для аудио/видео выберите файл";
                    isSubmitting = false;
                  });
                  return;
                }
                final uploadPayload =
                    selectedFileBytes != null && selectedFileName != null
                        ? MediaUploadPayload(
                          filename: selectedFileName!,
                          contentType:
                              selectedFileMime ??
                              _fallbackContentType(selectedType),
                          bytes: Uint8List.fromList(selectedFileBytes!),
                        )
                        : null;
                await widget.onAddItem(
                  type: selectedType,
                  title: titleController.text.trim(),
                  author:
                      authorController.text.trim().isEmpty
                          ? null
                          : authorController.text.trim(),
                  genres: selectedGenres.isEmpty ? null : selectedGenres,
                  coverUploadPayload:
                      selectedCoverFileName != null &&
                              selectedCoverFileBytes != null
                          ? MediaUploadPayload(
                            filename: selectedCoverFileName!,
                            contentType:
                                selectedCoverFileMime ??
                                _inferImageContentTypeFromName(
                                  selectedCoverFileName!,
                                ) ??
                                "image/jpeg",
                            bytes: Uint8List.fromList(selectedCoverFileBytes!),
                          )
                          : null,
                  uploadPayload: uploadPayload,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } on ApiException catch (e) {
                if (!context.mounted) {
                  return;
                }
                setDialogState(() {
                  submitError = e.message;
                  isSubmitting = false;
                });
              } catch (_) {
                if (!context.mounted) {
                  return;
                }
                setDialogState(() {
                  submitError =
                      "Не удалось добавить контент (неизвестная ошибка)";
                  isSubmitting = false;
                });
              }
            }

            return AlertDialog(
              title: const Text("Добавить контент"),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: "book", child: Text("Книга")),
                        DropdownMenuItem(
                          value: "audiobook",
                          child: Text("Аудиокнига"),
                        ),
                        DropdownMenuItem(value: "video", child: Text("Видео")),
                      ],
                      onChanged:
                          isSubmitting
                              ? null
                              : (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    selectedType = value;
                                    selectedFileName = null;
                                    selectedFileMime = null;
                                    selectedFileBytes = null;
                                    submitError = null;
                                  });
                                }
                              },
                      decoration: const InputDecoration(labelText: "Тип"),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleController,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(labelText: "Название"),
                      validator:
                          (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? "Укажите название"
                                  : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: authorController,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: "Автор (опционально)",
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey("add-genre-${selectedGenres.join("|")}"),
                      value: genrePickerValue,
                      items: genreOptions
                          .where(
                            (genre) =>
                                !selectedGenres.any(
                                  (selected) =>
                                      selected.toLowerCase() ==
                                      genre.toLowerCase(),
                                ),
                          )
                          .map(
                            (genre) => DropdownMenuItem(
                              value: genre,
                              child: Text(genre),
                            ),
                          )
                          .toList(growable: false),
                      onChanged:
                          isSubmitting
                              ? null
                              : (value) {
                                if (value == null) {
                                  return;
                                }
                                setDialogState(() {
                                  selectedGenres = [...selectedGenres, value];
                                  genrePickerValue = null;
                                });
                              },
                      decoration: const InputDecoration(
                        labelText: "Добавить жанр",
                      ),
                    ),
                    if (selectedGenres.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedGenres
                            .map(
                              (genre) => InputChip(
                                label: Text(genre),
                                onDeleted:
                                    isSubmitting
                                        ? null
                                        : () {
                                          setDialogState(() {
                                            selectedGenres = selectedGenres
                                                .where((g) => g != genre)
                                                .toList(growable: false);
                                          });
                                        },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed:
                          isSubmitting
                              ? null
                              : () async {
                                final result = await FilePicker.platform
                                    .pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: const [
                                        "jpg",
                                        "jpeg",
                                        "png",
                                        "webp",
                                      ],
                                      withData: true,
                                    );
                                if (!context.mounted ||
                                    result == null ||
                                    result.files.isEmpty) {
                                  return;
                                }
                                final file = result.files.first;
                                if (file.bytes == null || file.bytes!.isEmpty) {
                                  setDialogState(() {
                                    submitError =
                                        "Не удалось прочитать файл обложки";
                                  });
                                  return;
                                }
                                setDialogState(() {
                                  selectedCoverFileName = file.name;
                                  selectedCoverFileBytes = file.bytes!;
                                  selectedCoverFileMime =
                                      _inferImageContentTypeFromName(file.name);
                                  submitError = null;
                                });
                              },
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        selectedCoverFileName == null
                            ? "Выбрать обложку"
                            : "Обложка: $selectedCoverFileName",
                      ),
                    ),
                    if (selectedType == "book" ||
                        selectedType == "audiobook" ||
                        selectedType == "video") ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                            isSubmitting
                                ? null
                                : () async {
                                  final allowedExtensions =
                                      selectedType == "audiobook"
                                          ? const <String>[
                                            "mp3",
                                            "m4a",
                                            "aac",
                                            "wav",
                                            "ogg",
                                          ]
                                          : selectedType == "video"
                                          ? const <String>[
                                            "mp4",
                                            "mkv",
                                            "webm",
                                            "mov",
                                          ]
                                          : const <String>[
                                            "txt",
                                            "md",
                                            "pdf",
                                            "epub",
                                            "docx",
                                          ];
                                  final result = await FilePicker.platform
                                      .pickFiles(
                                        type: FileType.custom,
                                        allowedExtensions: allowedExtensions,
                                        withData: true,
                                      );
                                  if (!context.mounted ||
                                      result == null ||
                                      result.files.isEmpty) {
                                    return;
                                  }
                                  final file = result.files.first;
                                  if (file.bytes == null ||
                                      file.bytes!.isEmpty) {
                                    setDialogState(() {
                                      submitError =
                                          "Не удалось прочитать выбранный файл";
                                    });
                                    return;
                                  }
                                  setDialogState(() {
                                    selectedFileName = file.name;
                                    selectedFileBytes = file.bytes!;
                                    selectedFileMime =
                                        _inferContentTypeFromName(file.name) ??
                                        _fallbackContentType(selectedType);
                                    submitError = null;
                                  });
                                },
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          selectedFileName == null
                              ? "Выбрать файл"
                              : "Файл: $selectedFileName",
                        ),
                      ),
                      if (selectedFileName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          "Тип: ${selectedFileMime ?? "unknown"} • ${selectedFileBytes?.length ?? 0} bytes",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                    if (submitError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        submitError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text("Отмена"),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  child:
                      isSubmitting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text("Сохранить"),
                ),
              ],
            );
          },
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      titleController.dispose();
      authorController.dispose();
    });
  }

  String _fallbackContentType(String mediaType) {
    if (mediaType == "book") {
      return "text/plain";
    }
    if (mediaType == "audiobook") {
      return "audio/mpeg";
    }
    if (mediaType == "video") {
      return "video/mp4";
    }
    return "application/octet-stream";
  }

  bool _isFileCompatibleWithType({
    required String? filename,
    required String? mimeType,
    required String mediaType,
  }) {
    if (filename == null) {
      return true;
    }
    final normalizedMime =
        (mimeType ?? _inferContentTypeFromName(filename) ?? "")
            .trim()
            .toLowerCase();
    if (mediaType == "audiobook") {
      return normalizedMime.startsWith("audio/");
    }
    if (mediaType == "video") {
      return normalizedMime.startsWith("video/");
    }
    if (mediaType == "book") {
      return normalizedMime == "text/plain" ||
          normalizedMime == "text/markdown" ||
          normalizedMime == "application/pdf" ||
          normalizedMime == "application/epub+zip" ||
          normalizedMime ==
              "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    }
    return true;
  }

  String? _inferContentTypeFromName(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith(".txt")) return "text/plain";
    if (lower.endsWith(".md")) return "text/markdown";
    if (lower.endsWith(".pdf")) return "application/pdf";
    if (lower.endsWith(".epub")) return "application/epub+zip";
    if (lower.endsWith(".docx")) {
      return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    }
    if (lower.endsWith(".mp3")) return "audio/mpeg";
    if (lower.endsWith(".m4a")) return "audio/mp4";
    if (lower.endsWith(".aac")) return "audio/aac";
    if (lower.endsWith(".wav")) return "audio/wav";
    if (lower.endsWith(".ogg")) return "audio/ogg";
    if (lower.endsWith(".mp4")) return "video/mp4";
    if (lower.endsWith(".webm")) return "video/webm";
    if (lower.endsWith(".mov")) return "video/quicktime";
    if (lower.endsWith(".mkv")) return "video/x-matroska";
    return null;
  }

  String? _inferImageContentTypeFromName(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
      return "image/jpeg";
    }
    if (lower.endsWith(".png")) {
      return "image/png";
    }
    if (lower.endsWith(".webp")) {
      return "image/webp";
    }
    return null;
  }

  Future<void> _showLinksDialog(MediaListItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return FutureBuilder<List<MediaLinkItem>>(
          future: widget.onLoadLinks(item.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text("Не удалось загрузить связи")),
              );
            }
            final links = snapshot.data ?? const <MediaLinkItem>[];
            if (links.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text("Связей пока нет")),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final link = links[index];
                return ListTile(
                  leading: const Icon(Icons.link),
                  title: Text("Тип связи: ${link.relationType}"),
                  subtitle: Text(
                    "source: ${link.sourceMediaId}\ntarget: ${link.targetMediaId}",
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemCount: links.length,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Builder(
        builder: (context) {
          if (widget.isLoading && widget.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (widget.errorMessage != null && widget.items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _LibraryControls(
                  searchController: _searchController,
                  typeFilter: widget.typeFilter,
                  onApplyFilters: widget.onApplyFilters,
                  onAddPressed: _showAddDialog,
                  onSearchPressed: widget.onOpenSearchTab,
                ),
                const SizedBox(height: 64),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      widget.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }
          if (widget.items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _LibraryControls(
                  searchController: _searchController,
                  typeFilter: widget.typeFilter,
                  onApplyFilters: widget.onApplyFilters,
                  onAddPressed: _showAddDialog,
                  onSearchPressed: widget.onOpenSearchTab,
                ),
                const SizedBox(height: 64),
                Center(
                  child: Text(
                    widget.usingDemoItems
                        ? "Тестовые произведения не найдены по текущему фильтру"
                        : "Библиотека пока пустая",
                  ),
                ),
              ],
            );
          }
          final groups = _buildWorkGroups(widget.items);
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            children: [
              _LibraryControls(
                searchController: _searchController,
                typeFilter: widget.typeFilter,
                onApplyFilters: widget.onApplyFilters,
                onAddPressed: _showAddDialog,
                onSearchPressed: widget.onOpenSearchTab,
              ),
              if (widget.usingDemoItems) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Показаны тестовые произведения (backend вернул пустую библиотеку).",
                  ),
                ),
              ],
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                ),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _LibraryItemCard(
                    group: group,
                    onTap: () {
                      openMediaItemDetailsPage(
                        context: context,
                        currentUserId: widget.currentUserId,
                        groupItems: group.groupItems,
                        availableGenres: widget.availableGenres,
                        onLoadLinks: widget.onLoadLinks,
                        onLoadItemById: widget.onLoadItemById,
                        onUpdateItem: widget.onUpdateItem,
                        onAddFormatToWork: widget.onAddFormatToWork,
                        onBeginPlaybackSession: widget.onBeginPlaybackSession,
                        onPlaybackProgressChanged:
                            widget.onPlaybackProgressChanged,
                        onPausePlaybackSession: widget.onPausePlaybackSession,
                        onCompletePlaybackSession:
                            widget.onCompletePlaybackSession,
                        onFlushPlaybackSession: widget.onFlushPlaybackSession,
                        onEndPlaybackSession: widget.onEndPlaybackSession,
                        playbackSpeed: widget.playbackSpeed,
                        onSetPlaybackSpeed: widget.onSetPlaybackSpeed,
                        pendingPlaybackSync: widget.pendingPlaybackSync,
                        playbackError: widget.playbackError,
                        onLoadBookContent: widget.onLoadBookContent,
                        onMarkItemViewed: widget.onMarkItemViewed,
                      );
                    },
                    onOpenLinks: () => _showLinksDialog(group.primaryItem),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

String _labelForType(String type) {
  switch (type) {
    case "book":
      return "Книга";
    case "audiobook":
      return "Аудиокнига";
    case "video":
      return "Видео";
    default:
      return type;
  }
}

List<String> _uniqueGenres(Iterable<String> genres) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in genres) {
    final genre = raw.trim();
    if (genre.isEmpty) {
      continue;
    }
    final key = genre.toLowerCase();
    if (seen.contains(key)) {
      continue;
    }
    seen.add(key);
    result.add(genre);
  }
  return result;
}

String? _inferImageMimeFromFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
    return "image/jpeg";
  }
  if (lower.endsWith(".png")) {
    return "image/png";
  }
  if (lower.endsWith(".webp")) {
    return "image/webp";
  }
  return null;
}

Future<void> openMediaItemDetailsPage({
  required BuildContext context,
  required String? currentUserId,
  required List<MediaListItem> groupItems,
  required List<String> availableGenres,
  required Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks,
  required Future<MediaListItem?> Function(String mediaItemId) onLoadItemById,
  required Future<MediaListItem> Function({
    required String mediaItemId,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    MediaUploadPayload? uploadPayload,
    String? description,
  })
  onUpdateItem,
  required Future<MediaListItem> Function({
    required String sourceMediaItemId,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    String? description,
    MediaUploadPayload? uploadPayload,
  })
  onAddFormatToWork,
  required Future<PlaybackSessionConfig?> Function(MediaListItem item)
  onBeginPlaybackSession,
  required void Function({
    required int positionSeconds,
    required int? durationSeconds,
    required bool isPlaying,
    bool isCompleted,
  })
  onPlaybackProgressChanged,
  required Future<void> Function() onPausePlaybackSession,
  required Future<void> Function() onCompletePlaybackSession,
  required Future<void> Function() onFlushPlaybackSession,
  required void Function() onEndPlaybackSession,
  required double playbackSpeed,
  required void Function(double) onSetPlaybackSpeed,
  required bool pendingPlaybackSync,
  required String? playbackError,
  required Future<String> Function(MediaListItem item) onLoadBookContent,
  required void Function(String mediaItemId) onMarkItemViewed,
}) {
  if (groupItems.isNotEmpty) {
    onMarkItemViewed(groupItems.first.id);
  }
  final group = _WorkGroup(groupItems: groupItems);
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder:
          (_) => _MediaItemDetailsPage(
            currentUserId: currentUserId,
            group: group,
            availableGenres: availableGenres,
            onLoadLinks: onLoadLinks,
            onLoadItemById: onLoadItemById,
            onUpdateItem: onUpdateItem,
            onAddFormatToWork: onAddFormatToWork,
            onBeginPlaybackSession: onBeginPlaybackSession,
            onPlaybackProgressChanged: onPlaybackProgressChanged,
            onPausePlaybackSession: onPausePlaybackSession,
            onCompletePlaybackSession: onCompletePlaybackSession,
            onFlushPlaybackSession: onFlushPlaybackSession,
            onEndPlaybackSession: onEndPlaybackSession,
            playbackSpeed: playbackSpeed,
            onSetPlaybackSpeed: onSetPlaybackSpeed,
            pendingPlaybackSync: pendingPlaybackSync,
            playbackError: playbackError,
            onLoadBookContent: onLoadBookContent,
          ),
    ),
  );
}

class _WorkGroup {
  _WorkGroup({required this.groupItems});

  final List<MediaListItem> groupItems;

  MediaListItem get primaryItem => groupItems.first;
  String get displayTitle => primaryItem.title;
  String get displayAuthor => primaryItem.author ?? "";
  List<String> get types =>
      groupItems.map((item) => item.type).toSet().toList(growable: false)
        ..sort();
}

class _LibraryControls extends StatelessWidget {
  const _LibraryControls({
    required this.searchController,
    required this.typeFilter,
    required this.onApplyFilters,
    required this.onAddPressed,
    required this.onSearchPressed,
  });

  final TextEditingController searchController;
  final String? typeFilter;
  final Future<void> Function(String searchQuery, String? typeFilter)
  onApplyFilters;
  final Future<void> Function() onAddPressed;
  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    final selectedType = typeFilter ?? "all";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "Библиотека",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              onPressed: onSearchPressed,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          onSubmitted:
              (_) => onApplyFilters(searchController.text.trim(), typeFilter),
          decoration: InputDecoration(
            hintText: "Поиск в библиотеке...",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed:
                  () =>
                      onApplyFilters(searchController.text.trim(), typeFilter),
              icon: const Icon(Icons.filter_alt_outlined),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: "Все",
                selected: selectedType == "all",
                onTap: () => onApplyFilters(searchController.text.trim(), null),
              ),
              _FilterChip(
                label: "Книги",
                selected: selectedType == "book",
                onTap:
                    () => onApplyFilters(searchController.text.trim(), "book"),
              ),
              _FilterChip(
                label: "Аудиокниги",
                selected: selectedType == "audiobook",
                onTap:
                    () => onApplyFilters(
                      searchController.text.trim(),
                      "audiobook",
                    ),
              ),
              _FilterChip(
                label: "Видео",
                selected: selectedType == "video",
                onTap:
                    () => onApplyFilters(searchController.text.trim(), "video"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _LibraryItemCard extends StatelessWidget {
  const _LibraryItemCard({
    required this.group,
    required this.onTap,
    required this.onOpenLinks,
  });

  final _WorkGroup group;
  final VoidCallback onTap;
  final VoidCallback onOpenLinks;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child:
                          group.primaryItem.coverUrl?.isNotEmpty == true
                              ? Image.network(
                                group.primaryItem.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => const SizedBox.shrink(),
                              )
                              : const SizedBox.shrink(),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GestureDetector(
                      onTap: onOpenLinks,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).scaffoldBackgroundColor.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: group.types
                              .map(
                                (type) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Icon(_iconForType(type), size: 14),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            group.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            group.displayAuthor.isNotEmpty ? group.displayAuthor : "Без автора",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    if (type == "audiobook") {
      return Icons.headphones;
    }
    if (type == "video") {
      return Icons.videocam_outlined;
    }
    return Icons.menu_book_outlined;
  }
}

class _MediaItemDetailsPage extends StatefulWidget {
  const _MediaItemDetailsPage({
    required this.currentUserId,
    required this.group,
    required this.availableGenres,
    required this.onLoadLinks,
    required this.onLoadItemById,
    required this.onUpdateItem,
    required this.onAddFormatToWork,
    required this.onBeginPlaybackSession,
    required this.onPlaybackProgressChanged,
    required this.onPausePlaybackSession,
    required this.onCompletePlaybackSession,
    required this.onFlushPlaybackSession,
    required this.onEndPlaybackSession,
    required this.playbackSpeed,
    required this.onSetPlaybackSpeed,
    required this.pendingPlaybackSync,
    required this.playbackError,
    required this.onLoadBookContent,
  });

  final String? currentUserId;
  final _WorkGroup group;
  final List<String> availableGenres;
  final Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks;
  final Future<MediaListItem?> Function(String mediaItemId) onLoadItemById;
  final Future<MediaListItem> Function({
    required String mediaItemId,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    MediaUploadPayload? uploadPayload,
    String? description,
  })
  onUpdateItem;
  final Future<MediaListItem> Function({
    required String sourceMediaItemId,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    String? description,
    MediaUploadPayload? uploadPayload,
  })
  onAddFormatToWork;
  final Future<PlaybackSessionConfig?> Function(MediaListItem item)
  onBeginPlaybackSession;
  final void Function({
    required int positionSeconds,
    required int? durationSeconds,
    required bool isPlaying,
    bool isCompleted,
  })
  onPlaybackProgressChanged;
  final Future<void> Function() onPausePlaybackSession;
  final Future<void> Function() onCompletePlaybackSession;
  final Future<void> Function() onFlushPlaybackSession;
  final void Function() onEndPlaybackSession;
  final double playbackSpeed;
  final void Function(double) onSetPlaybackSpeed;
  final bool pendingPlaybackSync;
  final String? playbackError;
  final Future<String> Function(MediaListItem item) onLoadBookContent;

  @override
  State<_MediaItemDetailsPage> createState() => _MediaItemDetailsPageState();
}

class _MediaItemDetailsPageState extends State<_MediaItemDetailsPage> {
  late List<MediaListItem> _variants;
  bool _isLoadingLinked = false;

  String _fallbackContentType(String mediaType) {
    if (mediaType == "book") {
      return "text/plain";
    }
    if (mediaType == "audiobook") {
      return "audio/mpeg";
    }
    if (mediaType == "video") {
      return "video/mp4";
    }
    return "application/octet-stream";
  }

  bool _isFileCompatibleWithType({
    required String? filename,
    required String? mimeType,
    required String mediaType,
  }) {
    if (filename == null) {
      return true;
    }
    final normalizedMime =
        (mimeType ?? _inferContentTypeFromName(filename) ?? "")
            .trim()
            .toLowerCase();
    if (mediaType == "audiobook") {
      return normalizedMime.startsWith("audio/");
    }
    if (mediaType == "video") {
      return normalizedMime.startsWith("video/");
    }
    if (mediaType == "book") {
      return normalizedMime == "text/plain" ||
          normalizedMime == "text/markdown" ||
          normalizedMime == "application/pdf" ||
          normalizedMime == "application/epub+zip" ||
          normalizedMime ==
              "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    }
    return true;
  }

  String? _inferContentTypeFromName(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith(".txt")) return "text/plain";
    if (lower.endsWith(".md")) return "text/markdown";
    if (lower.endsWith(".pdf")) return "application/pdf";
    if (lower.endsWith(".epub")) return "application/epub+zip";
    if (lower.endsWith(".docx")) {
      return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    }
    if (lower.endsWith(".mp3")) return "audio/mpeg";
    if (lower.endsWith(".m4a")) return "audio/mp4";
    if (lower.endsWith(".aac")) return "audio/aac";
    if (lower.endsWith(".wav")) return "audio/wav";
    if (lower.endsWith(".ogg")) return "audio/ogg";
    if (lower.endsWith(".mp4")) return "video/mp4";
    if (lower.endsWith(".webm")) return "video/webm";
    if (lower.endsWith(".mov")) return "video/quicktime";
    if (lower.endsWith(".mkv")) return "video/x-matroska";
    return null;
  }

  @override
  void initState() {
    super.initState();
    _variants = List<MediaListItem>.from(widget.group.groupItems);
    _loadLinkedVariants();
  }

  Future<void> _loadLinkedVariants() async {
    setState(() {
      _isLoadingLinked = true;
    });

    final refreshedKnownVariants = <MediaListItem>[];
    for (final variant in _variants) {
      final fresh = await widget.onLoadItemById(variant.id);
      refreshedKnownVariants.add(fresh ?? variant);
    }
    _variants = refreshedKnownVariants;

    final knownIds = _variants.map((item) => item.id).toSet();
    final linkedIds = <String>{};
    for (final item in _variants) {
      final links = await widget.onLoadLinks(item.id);
      for (final link in links) {
        linkedIds.add(link.sourceMediaId);
        linkedIds.add(link.targetMediaId);
      }
    }

    for (final id in linkedIds) {
      if (knownIds.contains(id)) {
        continue;
      }
      final linkedItem = await widget.onLoadItemById(id);
      if (linkedItem != null) {
        _variants.add(linkedItem);
        knownIds.add(linkedItem.id);
      }
    }

    if (mounted) {
      _variants.sort((a, b) => a.type.compareTo(b.type));
      setState(() {
        _isLoadingLinked = false;
      });
    }
  }

  Future<void> _showEditVariantDialog(MediaListItem item) async {
    if (item.id.startsWith("demo-")) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Демо-произведения нельзя редактировать")),
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: item.title);
    final authorController = TextEditingController(text: item.author ?? "");
    List<String> selectedGenres = _uniqueGenres([...?item.genres]);
    String? selectedCoverFileName;
    List<int>? selectedCoverFileBytes;
    String? selectedCoverFileMime;
    String? selectedFileName;
    List<int>? selectedFileBytes;
    String? selectedFileMime;
    String? genrePickerValue;
    final descriptionController = TextEditingController(
      text: item.description ?? "",
    );
    String? submitError;
    bool isSubmitting = false;
    final genreOptions = _uniqueGenres(widget.availableGenres);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              setDialogState(() {
                isSubmitting = true;
                submitError = null;
              });
              try {
                final updated = await widget.onUpdateItem(
                  mediaItemId: item.id,
                  type: item.type,
                  title: titleController.text.trim(),
                  author: authorController.text.trim(),
                  genres: selectedGenres.isEmpty ? null : selectedGenres,
                  coverUploadPayload:
                      selectedCoverFileName != null &&
                              selectedCoverFileBytes != null
                          ? MediaUploadPayload(
                            filename: selectedCoverFileName!,
                            contentType:
                                selectedCoverFileMime ??
                                _inferImageMimeFromFilename(
                                  selectedCoverFileName!,
                                ) ??
                                "image/jpeg",
                            bytes: Uint8List.fromList(selectedCoverFileBytes!),
                          )
                          : null,
                  uploadPayload:
                      selectedFileName != null && selectedFileBytes != null
                          ? MediaUploadPayload(
                            filename: selectedFileName!,
                            contentType:
                                selectedFileMime ??
                                _fallbackContentType(item.type),
                            bytes: Uint8List.fromList(selectedFileBytes!),
                          )
                          : null,
                  description: descriptionController.text.trim(),
                );
                final refreshedUpdated =
                    await widget.onLoadItemById(item.id) ?? updated;
                if (!mounted) {
                  return;
                }
                setState(() {
                  final index = _variants.indexWhere((it) => it.id == item.id);
                  if (index >= 0) {
                    _variants[index] = refreshedUpdated;
                  }
                });
                Navigator.of(this.context).pop();
              } on ApiException catch (e) {
                setDialogState(() {
                  submitError = e.message;
                  isSubmitting = false;
                });
              } catch (_) {
                setDialogState(() {
                  submitError = "Не удалось сохранить изменения";
                  isSubmitting = false;
                });
              }
            }

            return AlertDialog(
              title: const Text("Редактировать данные"),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        enabled: !isSubmitting,
                        decoration: const InputDecoration(
                          labelText: "Название",
                        ),
                        validator:
                            (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? "Укажите название"
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: authorController,
                        enabled: !isSubmitting,
                        decoration: const InputDecoration(
                          labelText: "Автор (опционально)",
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey("edit-genre-${selectedGenres.join("|")}"),
                        value: genrePickerValue,
                        items: genreOptions
                            .where(
                              (genre) =>
                                  !selectedGenres.any(
                                    (selected) =>
                                        selected.toLowerCase() ==
                                        genre.toLowerCase(),
                                  ),
                            )
                            .map(
                              (genre) => DropdownMenuItem(
                                value: genre,
                                child: Text(genre),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            isSubmitting
                                ? null
                                : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setDialogState(() {
                                    selectedGenres = [...selectedGenres, value];
                                    genrePickerValue = null;
                                  });
                                },
                        decoration: const InputDecoration(
                          labelText: "Добавить жанр",
                        ),
                      ),
                      if (selectedGenres.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedGenres
                              .map(
                                (genre) => InputChip(
                                  label: Text(genre),
                                  onDeleted:
                                      isSubmitting
                                          ? null
                                          : () {
                                            setDialogState(() {
                                              selectedGenres = selectedGenres
                                                  .where((g) => g != genre)
                                                  .toList(growable: false);
                                            });
                                          },
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                            isSubmitting
                                ? null
                                : () async {
                                  final result = await FilePicker.platform
                                      .pickFiles(
                                        type: FileType.custom,
                                        allowedExtensions: const [
                                          "jpg",
                                          "jpeg",
                                          "png",
                                          "webp",
                                        ],
                                        withData: true,
                                      );
                                  if (!context.mounted ||
                                      result == null ||
                                      result.files.isEmpty) {
                                    return;
                                  }
                                  final file = result.files.first;
                                  if (file.bytes == null ||
                                      file.bytes!.isEmpty) {
                                    setDialogState(() {
                                      submitError =
                                          "Не удалось прочитать файл обложки";
                                    });
                                    return;
                                  }
                                  setDialogState(() {
                                    selectedCoverFileName = file.name;
                                    selectedCoverFileBytes = file.bytes!;
                                    selectedCoverFileMime =
                                        _inferImageMimeFromFilename(file.name);
                                  });
                                },
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          selectedCoverFileName == null
                              ? "Обновить обложку"
                              : "Обложка: $selectedCoverFileName",
                        ),
                      ),
                      if (item.type == "book" ||
                          item.type == "audiobook" ||
                          item.type == "video") ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed:
                              isSubmitting
                                  ? null
                                  : () async {
                                    final allowedExtensions =
                                        item.type == "audiobook"
                                            ? const <String>[
                                              "mp3",
                                              "m4a",
                                              "aac",
                                              "wav",
                                              "ogg",
                                            ]
                                            : item.type == "video"
                                            ? const <String>[
                                              "mp4",
                                              "mkv",
                                              "webm",
                                              "mov",
                                            ]
                                            : const <String>[
                                              "txt",
                                              "md",
                                              "pdf",
                                              "epub",
                                              "docx",
                                            ];
                                    final result = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: allowedExtensions,
                                          withData: true,
                                        );
                                    if (!context.mounted ||
                                        result == null ||
                                        result.files.isEmpty) {
                                      return;
                                    }
                                    final file = result.files.first;
                                    if (file.bytes == null ||
                                        file.bytes!.isEmpty) {
                                      setDialogState(() {
                                        submitError =
                                            "Не удалось прочитать выбранный файл";
                                      });
                                      return;
                                    }
                                    setDialogState(() {
                                      selectedFileName = file.name;
                                      selectedFileBytes = file.bytes!;
                                      selectedFileMime =
                                          _inferContentTypeFromName(
                                            file.name,
                                          ) ??
                                          _fallbackContentType(item.type);
                                      submitError = null;
                                    });
                                  },
                          icon: const Icon(Icons.attach_file_outlined),
                          label: Text(
                            selectedFileName == null
                                ? "Заменить файл"
                                : "Файл: $selectedFileName",
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        enabled: !isSubmitting,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: "Описание (опционально)",
                        ),
                      ),
                      if (submitError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          submitError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text("Отмена"),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  child:
                      isSubmitting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text("Сохранить"),
                ),
              ],
            );
          },
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      titleController.dispose();
      authorController.dispose();
      descriptionController.dispose();
    });
  }

  Future<void> _showAddFormatDialog() async {
    final sourceItem = _variants.first;
    if (sourceItem.id.startsWith("demo-")) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Для демо нельзя добавлять форматы")),
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(
      text: widget.group.displayTitle,
    );
    final authorController = TextEditingController(
      text: widget.group.displayAuthor,
    );
    final descriptionController = TextEditingController();
    List<String> selectedGenres = _uniqueGenres([
      ...(sourceItem.genres ?? const <String>[]),
    ]);
    String? selectedCoverFileName;
    List<int>? selectedCoverFileBytes;
    String? selectedCoverFileMime;
    String? genrePickerValue;
    String selectedType = "book";
    String? selectedFileName;
    String? selectedFileMime;
    List<int>? selectedFileBytes;
    String? submitError;
    bool isSubmitting = false;
    final genreOptions = _uniqueGenres(widget.availableGenres);

    final existingTypes = _variants.map((item) => item.type).toSet();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              if (existingTypes.contains(selectedType)) {
                setDialogState(() {
                  submitError = "Этот формат уже добавлен";
                });
                return;
              }
              if (selectedFileName != null &&
                  !_isFileCompatibleWithType(
                    filename: selectedFileName,
                    mimeType: selectedFileMime,
                    mediaType: selectedType,
                  )) {
                setDialogState(() {
                  submitError =
                      "Выбранный файл не подходит для типа $selectedType";
                });
                return;
              }
              final requiresUpload =
                  selectedType == "audiobook" || selectedType == "video";
              if (requiresUpload &&
                  (selectedFileName == null || selectedFileBytes == null)) {
                setDialogState(() {
                  submitError = "Для аудио/видео выберите файл";
                });
                return;
              }
              setDialogState(() {
                isSubmitting = true;
                submitError = null;
              });
              try {
                final created = await widget.onAddFormatToWork(
                  sourceMediaItemId: sourceItem.id,
                  type: selectedType,
                  title: titleController.text.trim(),
                  author: authorController.text.trim(),
                  genres: selectedGenres.isEmpty ? null : selectedGenres,
                  coverUploadPayload:
                      selectedCoverFileName != null &&
                              selectedCoverFileBytes != null
                          ? MediaUploadPayload(
                            filename: selectedCoverFileName!,
                            contentType:
                                selectedCoverFileMime ??
                                _inferImageMimeFromFilename(
                                  selectedCoverFileName!,
                                ) ??
                                "image/jpeg",
                            bytes: Uint8List.fromList(selectedCoverFileBytes!),
                          )
                          : null,
                  description: descriptionController.text.trim(),
                  uploadPayload:
                      selectedFileName != null && selectedFileBytes != null
                          ? MediaUploadPayload(
                            filename: selectedFileName!,
                            contentType:
                                selectedFileMime ??
                                _fallbackContentType(selectedType),
                            bytes: Uint8List.fromList(selectedFileBytes!),
                          )
                          : null,
                );
                if (!mounted) {
                  return;
                }
                setState(() {
                  _variants.add(created);
                  _variants.sort((a, b) => a.type.compareTo(b.type));
                });
                Navigator.of(this.context).pop();
              } on ApiException catch (e) {
                setDialogState(() {
                  submitError = e.message;
                  isSubmitting = false;
                });
              } catch (_) {
                setDialogState(() {
                  submitError = "Не удалось добавить формат";
                  isSubmitting = false;
                });
              }
            }

            return AlertDialog(
              title: const Text("Добавить формат"),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(labelText: "Тип"),
                        items: const [
                          DropdownMenuItem(value: "book", child: Text("Книга")),
                          DropdownMenuItem(
                            value: "audiobook",
                            child: Text("Аудиокнига"),
                          ),
                          DropdownMenuItem(
                            value: "video",
                            child: Text("Видео"),
                          ),
                        ],
                        onChanged:
                            isSubmitting
                                ? null
                                : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setDialogState(() {
                                    selectedType = value;
                                    selectedFileName = null;
                                    selectedFileMime = null;
                                    selectedFileBytes = null;
                                  });
                                },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleController,
                        enabled: !isSubmitting,
                        decoration: const InputDecoration(
                          labelText: "Название",
                        ),
                        validator:
                            (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? "Укажите название"
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: authorController,
                        enabled: !isSubmitting,
                        decoration: const InputDecoration(
                          labelText: "Автор (опционально)",
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          "format-genre-${selectedGenres.join("|")}",
                        ),
                        value: genrePickerValue,
                        items: genreOptions
                            .where(
                              (genre) =>
                                  !selectedGenres.any(
                                    (selected) =>
                                        selected.toLowerCase() ==
                                        genre.toLowerCase(),
                                  ),
                            )
                            .map(
                              (genre) => DropdownMenuItem(
                                value: genre,
                                child: Text(genre),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            isSubmitting
                                ? null
                                : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setDialogState(() {
                                    selectedGenres = [...selectedGenres, value];
                                    genrePickerValue = null;
                                  });
                                },
                        decoration: const InputDecoration(
                          labelText: "Добавить жанр",
                        ),
                      ),
                      if (selectedGenres.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedGenres
                              .map(
                                (genre) => InputChip(
                                  label: Text(genre),
                                  onDeleted:
                                      isSubmitting
                                          ? null
                                          : () {
                                            setDialogState(() {
                                              selectedGenres = selectedGenres
                                                  .where((g) => g != genre)
                                                  .toList(growable: false);
                                            });
                                          },
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                            isSubmitting
                                ? null
                                : () async {
                                  final result = await FilePicker.platform
                                      .pickFiles(
                                        type: FileType.custom,
                                        allowedExtensions: const [
                                          "jpg",
                                          "jpeg",
                                          "png",
                                          "webp",
                                        ],
                                        withData: true,
                                      );
                                  if (!context.mounted ||
                                      result == null ||
                                      result.files.isEmpty) {
                                    return;
                                  }
                                  final file = result.files.first;
                                  if (file.bytes == null ||
                                      file.bytes!.isEmpty) {
                                    setDialogState(() {
                                      submitError =
                                          "Не удалось прочитать файл обложки";
                                    });
                                    return;
                                  }
                                  setDialogState(() {
                                    selectedCoverFileName = file.name;
                                    selectedCoverFileBytes = file.bytes!;
                                    selectedCoverFileMime =
                                        _inferImageMimeFromFilename(file.name);
                                  });
                                },
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          selectedCoverFileName == null
                              ? "Выбрать обложку"
                              : "Обложка: $selectedCoverFileName",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        enabled: !isSubmitting,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: "Описание (опционально)",
                        ),
                      ),
                      if (selectedType == "book" ||
                          selectedType == "audiobook" ||
                          selectedType == "video") ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed:
                              isSubmitting
                                  ? null
                                  : () async {
                                    final allowedExtensions =
                                        selectedType == "audiobook"
                                            ? const <String>[
                                              "mp3",
                                              "m4a",
                                              "aac",
                                              "wav",
                                              "ogg",
                                            ]
                                            : selectedType == "video"
                                            ? const <String>[
                                              "mp4",
                                              "mkv",
                                              "webm",
                                              "mov",
                                            ]
                                            : const <String>[
                                              "txt",
                                              "md",
                                              "pdf",
                                              "epub",
                                              "docx",
                                            ];
                                    final result = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: allowedExtensions,
                                          withData: true,
                                        );
                                    if (!context.mounted ||
                                        result == null ||
                                        result.files.isEmpty) {
                                      return;
                                    }
                                    final file = result.files.first;
                                    if (file.bytes == null ||
                                        file.bytes!.isEmpty) {
                                      setDialogState(() {
                                        submitError =
                                            "Не удалось прочитать выбранный файл";
                                      });
                                      return;
                                    }
                                    setDialogState(() {
                                      selectedFileName = file.name;
                                      selectedFileBytes = file.bytes!;
                                      selectedFileMime =
                                          _inferContentTypeFromName(
                                            file.name,
                                          ) ??
                                          _fallbackContentType(selectedType);
                                    });
                                  },
                          icon: const Icon(Icons.attach_file),
                          label: Text(
                            selectedFileName == null
                                ? "Выбрать файл"
                                : "Файл: $selectedFileName",
                          ),
                        ),
                      ],
                      if (submitError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          submitError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text("Отмена"),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  child:
                      isSubmitting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text("Добавить"),
                ),
              ],
            );
          },
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      titleController.dispose();
      authorController.dispose();
      descriptionController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.group.displayTitle;
    if (_variants.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(title),
        ),
        body: const Center(child: Text("Нет доступных форм произведения")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
      ),
      body: DefaultTabController(
        length: _variants.length,
        child: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                final selectedIndex = tabController.index.clamp(
                  0,
                  _variants.length - 1,
                );
                final activeItem = _variants[selectedIndex];
                final activeAuthor =
                    activeItem.author?.trim().isNotEmpty == true
                        ? activeItem.author!.trim()
                        : "Не указан";
                final activeGenres = _uniqueGenres([...?activeItem.genres]);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 160,
                              width: 110,
                              child:
                                  activeItem.coverUrl?.isNotEmpty == true
                                      ? Image.network(
                                        activeItem.coverUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) => Container(
                                              color: Colors.black12,
                                              child: const Center(
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                ),
                                              ),
                                            ),
                                      )
                                      : Container(
                                        color: Colors.black12,
                                        child: const Center(
                                          child: Icon(
                                            Icons.image_not_supported_outlined,
                                          ),
                                        ),
                                      ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeItem.title,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(activeAuthor),
                                if (activeGenres.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        activeGenres
                                            .map((genre) => Chip(label: Text(genre)))
                                            .toList(growable: false),
                                  ),
                                ],
                                if (_isLoadingLinked) ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    "Загружаем связанные формы произведения...",
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    TabBar(
                      isScrollable: true,
                      tabs: _variants
                          .map((item) => Tab(text: _labelForType(item.type)))
                          .toList(growable: false),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: _variants
                            .map(
                              (item) => ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerLow,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Описание",
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.labelLarge,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.description?.isNotEmpty == true
                                                ? item.description!
                                                : "Описание отсутствует",
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (item.type == "book") ...[
                                    const SizedBox(height: 16),
                                    _BookContentPanel(
                                      item: item,
                                      onLoadBookContent: widget.onLoadBookContent,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (widget.currentUserId != null &&
                                          item.userId == widget.currentUserId)
                                        OutlinedButton.icon(
                                          onPressed:
                                              () => _showEditVariantDialog(item),
                                          icon: const Icon(Icons.edit),
                                          label: const Text("Редактировать"),
                                        ),
                                      FilledButton.icon(
                                        onPressed: _showAddFormatDialog,
                                        icon: const Icon(Icons.add_circle_outline),
                                        label: const Text("Добавить формат"),
                                      ),
                                    ],
                                  ),
                                  if (item.type == "audiobook" ||
                                      item.type == "video") ...[
                                    const SizedBox(height: 16),
                                    _PlayableMediaPanel(
                                      item: item,
                                      onBeginPlaybackSession:
                                          widget.onBeginPlaybackSession,
                                      onPlaybackProgressChanged:
                                          widget.onPlaybackProgressChanged,
                                      onPausePlaybackSession:
                                          widget.onPausePlaybackSession,
                                      onCompletePlaybackSession:
                                          widget.onCompletePlaybackSession,
                                      onFlushPlaybackSession:
                                          widget.onFlushPlaybackSession,
                                      onEndPlaybackSession:
                                          widget.onEndPlaybackSession,
                                      playbackSpeed: widget.playbackSpeed,
                                      onSetPlaybackSpeed:
                                          widget.onSetPlaybackSpeed,
                                      pendingPlaybackSync:
                                          widget.pendingPlaybackSync,
                                      playbackError: widget.playbackError,
                                    ),
                                  ],
                                ],
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BookContentPanel extends StatefulWidget {
  const _BookContentPanel({
    required this.item,
    required this.onLoadBookContent,
  });

  final MediaListItem item;
  final Future<String> Function(MediaListItem item) onLoadBookContent;

  @override
  State<_BookContentPanel> createState() => _BookContentPanelState();
}

class _BookContentPanelState extends State<_BookContentPanel> {
  late Future<String> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = widget.onLoadBookContent(widget.item);
  }

  @override
  void didUpdateWidget(covariant _BookContentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _contentFuture = widget.onLoadBookContent(widget.item);
    }
  }

  void _reload() {
    setState(() {
      _contentFuture = widget.onLoadBookContent(widget.item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Текст книги"),
              SizedBox(height: 8),
              LinearProgressIndicator(),
            ],
          );
        }
        if (snapshot.hasError) {
          final message = snapshot.error?.toString() ?? "Неизвестная ошибка";
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Текст книги"),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text("Повторить"),
              ),
            ],
          );
        }

        final content = snapshot.data ?? "";
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Текст книги"),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 360),
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withAlpha(70),
                child: SingleChildScrollView(
                  child: SelectableText(
                    content,
                    style: const TextStyle(height: 1.35),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayableMediaPanel extends StatefulWidget {
  const _PlayableMediaPanel({
    required this.item,
    required this.onBeginPlaybackSession,
    required this.onPlaybackProgressChanged,
    required this.onPausePlaybackSession,
    required this.onCompletePlaybackSession,
    required this.onFlushPlaybackSession,
    required this.onEndPlaybackSession,
    required this.playbackSpeed,
    required this.onSetPlaybackSpeed,
    required this.pendingPlaybackSync,
    required this.playbackError,
  });

  final MediaListItem item;
  final Future<PlaybackSessionConfig?> Function(MediaListItem item)
  onBeginPlaybackSession;
  final void Function({
    required int positionSeconds,
    required int? durationSeconds,
    required bool isPlaying,
    bool isCompleted,
  })
  onPlaybackProgressChanged;
  final Future<void> Function() onPausePlaybackSession;
  final Future<void> Function() onCompletePlaybackSession;
  final Future<void> Function() onFlushPlaybackSession;
  final void Function() onEndPlaybackSession;
  final double playbackSpeed;
  final void Function(double) onSetPlaybackSpeed;
  final bool pendingPlaybackSync;
  final String? playbackError;

  @override
  State<_PlayableMediaPanel> createState() => _PlayableMediaPanelState();
}

class _PlayableMediaPanelState extends State<_PlayableMediaPanel> {
  static const List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5, 2.0];

  AudioPlayer? _audioPlayer;
  VideoPlayerController? _videoController;
  StreamSubscription<Duration>? _audioPositionSub;
  StreamSubscription<Duration?>? _audioDurationSub;
  StreamSubscription<PlayerState>? _audioPlayerStateSub;
  StreamSubscription<PlaybackEvent>? _audioPlaybackEventSub;

  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isReady = false;
  String? _localError;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _sessionStarted = false;
  bool _didRetryPrepare = false;
  bool _isRecoveringStream = false;
  late double _currentSpeed;
  double _videoVolume = 1.0;
  bool _showControls = false;
  Timer? _controlsHideTimer;

  bool get _isAudio => widget.item.type == "audiobook";
  bool get _isVideo => widget.item.type == "video";

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.playbackSpeed;
    if (_isVideo) {
      unawaited(_prepareIfNeeded());
    }
  }

  @override
  void didUpdateWidget(covariant _PlayableMediaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id ||
        widget.item.type != oldWidget.item.type) {
      unawaited(_reinitializeForItemChange());
      return;
    }
    if (widget.playbackSpeed != oldWidget.playbackSpeed &&
        widget.playbackSpeed != _currentSpeed) {
      _currentSpeed = widget.playbackSpeed;
    }
  }

  Future<void> _reinitializeForItemChange() async {
    await _disposePlayers();
    if (!mounted) {
      return;
    }
    setState(() {
      _isInitializing = false;
      _isPlaying = false;
      _isReady = false;
      _localError = null;
      _position = Duration.zero;
      _duration = null;
      _sessionStarted = false;
      _didRetryPrepare = false;
      _isRecoveringStream = false;
      _videoVolume = 1.0;
      _showControls = false;
    });
    if (_isVideo) {
      unawaited(_prepareIfNeeded());
    }
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    unawaited(_disposePlayers());
    super.dispose();
  }

  Future<void> _disposePlayers() async {
    await _audioPositionSub?.cancel();
    await _audioDurationSub?.cancel();
    await _audioPlayerStateSub?.cancel();
    await _audioPlaybackEventSub?.cancel();
    _audioPositionSub = null;
    _audioDurationSub = null;
    _audioPlayerStateSub = null;
    _audioPlaybackEventSub = null;
    if (_audioPlayer != null) {
      await _audioPlayer!.dispose();
      _audioPlayer = null;
    }
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoControllerUpdate);
      await _videoController!.dispose();
      _videoController = null;
    }
    if (_sessionStarted) {
      await widget.onFlushPlaybackSession();
      widget.onEndPlaybackSession();
      _sessionStarted = false;
    }
  }

  Future<void> _prepareIfNeeded() async {
    if (_isReady || _isInitializing) {
      return;
    }
    setState(() {
      _isInitializing = true;
      _localError = null;
    });

    final config = await widget.onBeginPlaybackSession(widget.item);
    if (!mounted) {
      return;
    }
    if (config == null) {
      setState(() {
        _isInitializing = false;
        _localError = widget.playbackError ?? "Не удалось подготовить плеер";
      });
      return;
    }

    try {
      if (_isAudio) {
        final player = AudioPlayer();
        _audioPlayer = player;
        _audioPositionSub = player.positionStream.listen((position) {
          final totalDuration = _duration ?? player.duration;
          widget.onPlaybackProgressChanged(
            positionSeconds: position.inSeconds,
            durationSeconds: totalDuration?.inSeconds,
            isPlaying: player.playing,
            isCompleted: false,
          );
          if (mounted) {
            setState(() {
              _position = position;
              _duration = totalDuration;
            });
          }
        });
        _audioDurationSub = player.durationStream.listen((duration) {
          if (duration != null && mounted) {
            setState(() {
              _duration = duration;
            });
          }
        });
        _audioPlayerStateSub = player.playerStateStream.listen((state) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isPlaying = state.playing;
          });
          if (state.processingState == ProcessingState.completed) {
            widget.onPlaybackProgressChanged(
              positionSeconds: (_duration ?? _position).inSeconds,
              durationSeconds: _duration?.inSeconds,
              isPlaying: false,
              isCompleted: true,
            );
            unawaited(widget.onCompletePlaybackSession());
          }
        });
        _audioPlaybackEventSub = player.playbackEventStream.listen(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            unawaited(_recoverFromStreamError(error));
            if (!mounted) {
              return;
            }
            setState(() {
              _localError = _humanizePlaybackError(error);
            });
          },
        );
        await player.setUrl(
          config.streamUrl,
          initialPosition: Duration(seconds: config.initialPositionSeconds),
        );
        await player.setSpeed(_currentSpeed);
        if (!mounted) {
          return;
        }
        _position = Duration(seconds: config.initialPositionSeconds);
        _duration = player.duration ?? _duration;
      } else if (_isVideo) {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(config.streamUrl),
        );
        _videoController = controller;
        await controller.initialize();
        await controller.setVolume(_videoVolume);
        if (!mounted) {
          return;
        }
        if (config.initialPositionSeconds > 0) {
          await controller.seekTo(
            Duration(seconds: config.initialPositionSeconds),
          );
        }
        await controller.setPlaybackSpeed(_currentSpeed);
        if (!mounted) {
          return;
        }
        controller.addListener(_onVideoControllerUpdate);
        _position = controller.value.position;
        _duration = controller.value.duration;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isReady = true;
        _isInitializing = false;
        _sessionStarted = true;
        _didRetryPrepare = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isRetryablePlaybackError(error) && !_didRetryPrepare) {
        _didRetryPrepare = true;
        await _disposePlayers();
        if (!mounted) {
          return;
        }
        setState(() {
          _isInitializing = false;
          _localError = null;
        });
        await _prepareIfNeeded();
        return;
      }
      setState(() {
        _isInitializing = false;
        _localError = _humanizePlaybackError(error);
      });
    }
  }

  void _onVideoControllerUpdate() {
    final controller = _videoController;
    if (controller == null || !mounted) {
      return;
    }
    final value = controller.value;
    setState(() {
      _position = value.position;
      _duration = value.duration;
      _isPlaying = value.isPlaying;
    });
    widget.onPlaybackProgressChanged(
      positionSeconds: value.position.inSeconds,
      durationSeconds:
          value.duration.inSeconds > 0 ? value.duration.inSeconds : null,
      isPlaying: value.isPlaying,
      isCompleted: value.isCompleted,
    );
    if (value.isCompleted) {
      unawaited(widget.onCompletePlaybackSession());
    }
  }

  Future<void> _togglePlayPause() async {
    await _prepareIfNeeded();
    if (!_isReady) {
      return;
    }
    if (_isAudio && _audioPlayer != null) {
      try {
        if (_audioPlayer!.playing) {
          await _audioPlayer!.pause();
          await widget.onPausePlaybackSession();
        } else {
          await _audioPlayer!.play();
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _localError = _humanizePlaybackError(error);
          });
        }
      }
      if (mounted) {
        setState(() {
          _isPlaying = _audioPlayer!.playing;
        });
      }
      _showControlsTemporarily();
      return;
    }
    if (_isVideo && _videoController != null) {
      if (_videoController!.value.isPlaying) {
        await _videoController!.pause();
        await widget.onPausePlaybackSession();
      } else {
        await _videoController!.play();
      }
      if (mounted) {
        setState(() {
          _isPlaying = _videoController!.value.isPlaying;
        });
      }
      _showControlsTemporarily();
    }
  }

  Future<void> _seekTo(double value) async {
    final seekPosition = Duration(seconds: value.round());
    if (_isAudio && _audioPlayer != null) {
      await _audioPlayer!.seek(seekPosition);
      widget.onPlaybackProgressChanged(
        positionSeconds: seekPosition.inSeconds,
        durationSeconds: _duration?.inSeconds,
        isPlaying: _audioPlayer!.playing,
      );
    } else if (_isVideo && _videoController != null) {
      await _videoController!.seekTo(seekPosition);
      widget.onPlaybackProgressChanged(
        positionSeconds: seekPosition.inSeconds,
        durationSeconds: _duration?.inSeconds,
        isPlaying: _videoController!.value.isPlaying,
      );
    }
    _showControlsTemporarily();
  }

  Future<void> _changeSpeed(double speed) async {
    _currentSpeed = speed;
    widget.onSetPlaybackSpeed(speed);
    if (_isAudio && _audioPlayer != null) {
      await _audioPlayer!.setSpeed(speed);
    } else if (_isVideo && _videoController != null) {
      await _videoController!.setPlaybackSpeed(speed);
    }
    if (mounted) {
      setState(() {});
    }
    _showControlsTemporarily();
  }

  Future<void> _toggleMute() async {
    if (!_isVideo || _videoController == null) {
      return;
    }
    final nextVolume = _videoVolume > 0 ? 0.0 : 1.0;
    await _videoController!.setVolume(nextVolume);
    if (mounted) {
      setState(() {
        _videoVolume = nextVolume;
      });
    }
    _showControlsTemporarily();
  }

  Future<void> _openFullscreenVideo(BuildContext context) async {
    final controller = _videoController;
    if (!_isVideo || controller == null || !controller.value.isInitialized) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: GestureDetector(
                  onTap: _toggleControlsVisibility,
                  onVerticalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > 500) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Stack(
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
                      if (_showControls)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip:
                                    _videoVolume > 0
                                        ? "Выключить звук"
                                        : "Включить звук",
                                onPressed: _toggleMute,
                                color: Colors.white,
                                icon: Icon(
                                  _videoVolume > 0
                                      ? Icons.volume_up
                                      : Icons.volume_off,
                                ),
                              ),
                              PopupMenuButton<double>(
                                tooltip: "Скорость",
                                initialValue: _currentSpeed,
                                onSelected: _changeSpeed,
                                itemBuilder:
                                    (context) => _speedOptions
                                        .map(
                                          (speed) => PopupMenuItem<double>(
                                            value: speed,
                                            child: Text(
                                              "${speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2)}x",
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                icon: const Icon(
                                  Icons.speed,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                      if (_showControls)
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: controller,
                          builder: (context, value, child) {
                            final totalSeconds = value.duration.inSeconds;
                            final currentSeconds = value.position.inSeconds
                                .clamp(0, totalSeconds > 0 ? totalSeconds : 0);
                            return Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white30,
                                        thumbColor: Colors.white,
                                        trackHeight: 2,
                                      ),
                                      child: Slider(
                                        value: currentSeconds.toDouble(),
                                        max: (totalSeconds > 0 ? totalSeconds : 1)
                                            .toDouble(),
                                        onChanged:
                                            (_isReady && totalSeconds > 0)
                                                ? _seekTo
                                                : null,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _formatDuration(value.position),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          onPressed:
                                              _isInitializing
                                                  ? null
                                                  : _togglePlayPause,
                                          color: Colors.white,
                                          icon: Icon(
                                            value.isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatDuration(value.duration),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleControlsVisibility() {
    if (_showControls) {
      _controlsHideTimer?.cancel();
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
      return;
    }
    _showControlsTemporarily();
  }

  void _showControlsTemporarily() {
    _controlsHideTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _showControls = true;
    });
    if (!_isPlaying) {
      return;
    }
    _controlsHideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showControls = false;
      });
    });
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) {
      return "--:--";
    }
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, "0");
    final seconds = (totalSeconds % 60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }

  String _humanizePlaybackError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains("404")) {
      return "Аудиофайл не найден (HTTP 404). Проверьте, что файл загружен и file_id актуален.";
    }
    if (lower.contains("sockettimeoutexception") ||
        lower.contains("failed to connect") ||
        lower.contains("connection timed out")) {
      return "Не удалось подключиться к хранилищу аудио. Для эмулятора проверьте доступность endpoint на 10.0.2.2.";
    }
    if (lower.contains("cleartext")) {
      return "Поток заблокирован политикой cleartext HTTP. Нужен HTTPS или network security config.";
    }
    if (lower.contains("source error")) {
      return "Источник аудио недоступен (обычно 404/403). Проверьте, что файл существует в storage и media_file_id актуален.";
    }
    return "Ошибка воспроизведения: $raw";
  }

  bool _isRetryablePlaybackError(Object error) {
    final lower = error.toString().toLowerCase();
    return lower.contains("404") ||
        lower.contains("403") ||
        lower.contains("response code");
  }

  Future<void> _recoverFromStreamError(Object error) async {
    if (!mounted || !_isRetryablePlaybackError(error)) {
      return;
    }
    if (_didRetryPrepare || _isRecoveringStream) {
      return;
    }
    _isRecoveringStream = true;
    _didRetryPrepare = true;
    final shouldResumePlayback = _isPlaying;
    try {
      await _disposePlayers();
      if (!mounted) {
        return;
      }
      await _prepareIfNeeded();
      if (!mounted || !shouldResumePlayback) {
        return;
      }
      if (_isAudio && _audioPlayer != null) {
        await _audioPlayer!.play();
      } else if (_isVideo && _videoController != null) {
        await _videoController!.play();
      }
    } catch (_) {
      // Keep original playback error visible for the user.
    } finally {
      _isRecoveringStream = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentError = _localError ?? widget.playbackError;
    final totalSeconds = (_duration ?? Duration.zero).inSeconds;
    final currentSeconds = _position.inSeconds.clamp(
      0,
      totalSeconds > 0 ? totalSeconds : 0,
    );
    final isVideoReady = _videoController?.value.isInitialized == true;
    final previewAspectRatio =
        isVideoReady ? _videoController!.value.aspectRatio : 16 / 9;
    final hasCover = widget.item.coverUrl?.isNotEmpty == true;

    if (_isAudio) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child:
                          hasCover
                              ? Image.network(
                                widget.item.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => Container(
                                      color: Colors.black12,
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.headphones),
                                    ),
                              )
                              : Container(
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(Icons.headphones),
                              ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Аудиоплеер",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<double>(
                    tooltip: "Скорость",
                    initialValue: _currentSpeed,
                    onSelected: _changeSpeed,
                    itemBuilder:
                        (context) => _speedOptions
                            .map(
                              (speed) => PopupMenuItem<double>(
                                value: speed,
                                child: Text(
                                  "${speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2)}x",
                                ),
                              ),
                            )
                            .toList(growable: false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        "${_currentSpeed.toStringAsFixed(_currentSpeed == _currentSpeed.roundToDouble() ? 0 : 2)}x",
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Slider(
                value: currentSeconds.toDouble(),
                max: (totalSeconds > 0 ? totalSeconds : 1).toDouble(),
                onChanged: (_isReady && totalSeconds > 0) ? _seekTo : null,
              ),
              Row(
                children: [
                  Text(_formatDuration(_position)),
                  const Spacer(),
                  Text(_formatDuration(_duration)),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _isInitializing ? null : _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isPlaying ? "Пауза" : "Воспроизвести"),
                ),
              ),
              if (_isInitializing) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (currentError != null) ...[
                const SizedBox(height: 8),
                Text(
                  currentError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _toggleControlsVisibility,
              child: AspectRatio(
                aspectRatio: previewAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isVideo && isVideoReady)
                        VideoPlayer(_videoController!)
                      else if (hasCover)
                        Image.network(
                          widget.item.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Container(
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  size: 40,
                                ),
                              ),
                        )
                      else
                        Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: Icon(
                            _isAudio ? Icons.headphones : Icons.ondemand_video,
                            size: 40,
                          ),
                        ),
                      AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Container(color: Colors.black38),
                      ),
                      if (_isInitializing)
                        const Center(child: CircularProgressIndicator()),
                      AnimatedOpacity(
                        opacity: _showControls || !_isPlaying ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Center(
                          child: IconButton.filledTonal(
                            onPressed: _isInitializing ? null : _togglePlayPause,
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      if (_showControls)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isVideo && isVideoReady)
                                IconButton(
                                  tooltip:
                                      _videoVolume > 0
                                          ? "Выключить звук"
                                          : "Включить звук",
                                  onPressed: _toggleMute,
                                  color: Colors.white,
                                  icon: Icon(
                                    _videoVolume > 0
                                        ? Icons.volume_up
                                        : Icons.volume_off,
                                  ),
                                ),
                              if (_isVideo && isVideoReady)
                                IconButton(
                                  tooltip: "Полный экран",
                                  onPressed: () => _openFullscreenVideo(context),
                                  color: Colors.white,
                                  icon: const Icon(Icons.fullscreen),
                                ),
                              PopupMenuButton<double>(
                                tooltip: "Скорость",
                                initialValue: _currentSpeed,
                                onSelected: _changeSpeed,
                                itemBuilder:
                                    (context) => _speedOptions
                                        .map(
                                          (speed) => PopupMenuItem<double>(
                                            value: speed,
                                            child: Text(
                                              "${speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2)}x",
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${_currentSpeed.toStringAsFixed(_currentSpeed == _currentSpeed.roundToDouble() ? 0 : 2)}x",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_showControls)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white30,
                                    thumbColor: Colors.white,
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 5,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 10,
                                    ),
                                  ),
                                  child: Slider(
                                    value: currentSeconds.toDouble(),
                                    max: (totalSeconds > 0 ? totalSeconds : 1)
                                        .toDouble(),
                                    onChanged:
                                        (_isReady && totalSeconds > 0)
                                            ? _seekTo
                                            : null,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _formatDuration(_position),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDuration(_duration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (currentError != null) ...[
              const SizedBox(height: 8),
              Text(
                currentError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
