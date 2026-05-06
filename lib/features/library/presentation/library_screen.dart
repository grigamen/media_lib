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
    required this.items,
    required this.usingDemoItems,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.searchQuery,
    required this.typeFilter,
    required this.onApplyFilters,
    required this.onAddItem,
    required this.onLoadLinks,
    required this.onLoadItemById,
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
    super.key,
  });

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
    MediaUploadPayload? uploadPayload,
  })
  onAddItem;
  final Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks;
  final Future<MediaListItem?> Function(String mediaItemId) onLoadItemById;
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
    String? submitError;
    bool isSubmitting = false;

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
                final isPlayableType =
                    selectedType == "audiobook" || selectedType == "video";
                if (isPlayableType &&
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
                    if (selectedType == "audiobook" ||
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
                                          : const <String>[
                                            "mp4",
                                            "mkv",
                                            "webm",
                                            "mov",
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
    if (mediaType == "audiobook") {
      return "audio/mpeg";
    }
    if (mediaType == "video") {
      return "video/mp4";
    }
    return "application/octet-stream";
  }

  String? _inferContentTypeFromName(String filename) {
    final lower = filename.toLowerCase();
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
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LibraryControls(
                      searchController: _searchController,
                      typeFilter: widget.typeFilter,
                      onApplyFilters: widget.onApplyFilters,
                      onAddPressed: _showAddDialog,
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
                  ],
                );
              }
              final group = groups[index - 1];
              final firstChar =
                  group.displayTitle.isNotEmpty
                      ? group.displayTitle.substring(0, 1).toUpperCase()
                      : "?";
              return ListTile(
                leading: CircleAvatar(child: Text(firstChar)),
                title: Text(group.displayTitle),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (group.displayAuthor.isNotEmpty)
                      Text(group.displayAuthor),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: -8,
                      children: group.types
                          .map(
                            (type) => Chip(
                              label: Text(_labelForType(type)),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
                isThreeLine: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => _MediaItemDetailsPage(
                            group: group,
                            onLoadLinks: widget.onLoadLinks,
                            onLoadItemById: widget.onLoadItemById,
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
                            onEndPlaybackSession: widget.onEndPlaybackSession,
                            playbackSpeed: widget.playbackSpeed,
                            onSetPlaybackSpeed: widget.onSetPlaybackSpeed,
                            pendingPlaybackSync: widget.pendingPlaybackSync,
                            playbackError: widget.playbackError,
                          ),
                    ),
                  );
                },
                trailing: IconButton(
                  tooltip: "Связи",
                  icon: const Icon(Icons.link),
                  onPressed: () => _showLinksDialog(group.primaryItem),
                ),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemCount: groups.length + 1,
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
  });

  final TextEditingController searchController;
  final String? typeFilter;
  final Future<void> Function(String searchQuery, String? typeFilter)
  onApplyFilters;
  final Future<void> Function() onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchController,
          onSubmitted:
              (_) => onApplyFilters(searchController.text.trim(), typeFilter),
          decoration: InputDecoration(
            hintText: "Поиск по названию/автору",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed:
                  () =>
                      onApplyFilters(searchController.text.trim(), typeFilter),
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: typeFilter ?? "all",
                items: const [
                  DropdownMenuItem(value: "all", child: Text("Все типы")),
                  DropdownMenuItem(value: "book", child: Text("Книги")),
                  DropdownMenuItem(
                    value: "audiobook",
                    child: Text("Аудиокниги"),
                  ),
                  DropdownMenuItem(value: "video", child: Text("Видео")),
                ],
                onChanged: (value) {
                  final selected =
                      value == null || value == "all" ? null : value;
                  onApplyFilters(searchController.text.trim(), selected);
                },
                decoration: const InputDecoration(labelText: "Фильтр по типу"),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text("Добавить"),
            ),
          ],
        ),
      ],
    );
  }
}

class _MediaItemDetailsPage extends StatefulWidget {
  const _MediaItemDetailsPage({
    required this.group,
    required this.onLoadLinks,
    required this.onLoadItemById,
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

  final _WorkGroup group;
  final Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks;
  final Future<MediaListItem?> Function(String mediaItemId) onLoadItemById;
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
  State<_MediaItemDetailsPage> createState() => _MediaItemDetailsPageState();
}

class _MediaItemDetailsPageState extends State<_MediaItemDetailsPage> {
  late List<MediaListItem> _variants;
  bool _isLoadingLinked = false;

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

  @override
  Widget build(BuildContext context) {
    final title = widget.group.displayTitle;
    final author = widget.group.displayAuthor;
    if (_variants.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text("Нет доступных форм произведения")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: DefaultTabController(
        length: _variants.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text("Автор: ${author.isNotEmpty ? author : "Не указан"}"),
                  if (_isLoadingLinked) ...[
                    const SizedBox(height: 6),
                    const Text("Загружаем связанные формы произведения..."),
                  ],
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
                          Text("Тип: ${_labelForType(item.type)}"),
                          const SizedBox(height: 6),
                          Text("Название: ${item.title}"),
                          const SizedBox(height: 6),
                          Text(
                            "Автор: ${item.author?.isNotEmpty == true ? item.author : "Не указан"}",
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.description?.isNotEmpty == true
                                ? item.description!
                                : "Описание отсутствует",
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
                              onEndPlaybackSession: widget.onEndPlaybackSession,
                              playbackSpeed: widget.playbackSpeed,
                              onSetPlaybackSpeed: widget.onSetPlaybackSpeed,
                              pendingPlaybackSync: widget.pendingPlaybackSync,
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
        ),
      ),
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

  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isReady = false;
  String? _localError;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _sessionStarted = false;

  bool get _isAudio => widget.item.type == "audiobook";
  bool get _isVideo => widget.item.type == "video";

  @override
  void dispose() {
    unawaited(_disposePlayers());
    super.dispose();
  }

  Future<void> _disposePlayers() async {
    await _audioPositionSub?.cancel();
    await _audioDurationSub?.cancel();
    await _audioPlayerStateSub?.cancel();
    _audioPositionSub = null;
    _audioDurationSub = null;
    _audioPlayerStateSub = null;
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
        await player.setUrl(
          config.streamUrl,
          initialPosition: Duration(seconds: config.initialPositionSeconds),
        );
        await player.setSpeed(widget.playbackSpeed);
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
        if (!mounted) {
          return;
        }
        if (config.initialPositionSeconds > 0) {
          await controller.seekTo(
            Duration(seconds: config.initialPositionSeconds),
          );
        }
        await controller.setPlaybackSpeed(widget.playbackSpeed);
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
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _localError = "Не удалось загрузить поток воспроизведения";
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
      if (_audioPlayer!.playing) {
        await _audioPlayer!.pause();
        await widget.onPausePlaybackSession();
      } else {
        await _audioPlayer!.play();
      }
      if (mounted) {
        setState(() {
          _isPlaying = _audioPlayer!.playing;
        });
      }
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
  }

  Future<void> _changeSpeed(double speed) async {
    widget.onSetPlaybackSpeed(speed);
    if (_isAudio && _audioPlayer != null) {
      await _audioPlayer!.setSpeed(speed);
    } else if (_isVideo && _videoController != null) {
      await _videoController!.setPlaybackSpeed(speed);
    }
    if (mounted) {
      setState(() {});
    }
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

  @override
  Widget build(BuildContext context) {
    final currentError = _localError ?? widget.playbackError;
    final totalSeconds = (_duration ?? Duration.zero).inSeconds;
    final currentSeconds = _position.inSeconds.clamp(
      0,
      totalSeconds > 0 ? totalSeconds : 0,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_isAudio ? Icons.headphones : Icons.ondemand_video),
                const SizedBox(width: 8),
                Text(_isAudio ? "Аудиоплеер" : "Видеоплеер"),
                const Spacer(),
                PopupMenuButton<double>(
                  tooltip: "Скорость",
                  initialValue: widget.playbackSpeed,
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
                    child: Text("${widget.playbackSpeed.toStringAsFixed(2)}x"),
                  ),
                ),
              ],
            ),
            if (_isVideo &&
                _videoController != null &&
                _videoController!.value.isInitialized) ...[
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ],
            const SizedBox(height: 8),
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
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isInitializing ? null : _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isPlaying ? "Пауза" : "Play"),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed:
                      _sessionStarted ? widget.onFlushPlaybackSession : null,
                  child: const Text("Синхронизировать"),
                ),
                if (widget.pendingPlaybackSync) ...[
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Ожидает синхронизации...",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
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
}
