part of 'library_screen.dart';

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
                final created = await widget.onAddItem(
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
                  final msg =
                      created?.moderationStatus == "pending"
                          ? "Произведение отправлено на модерацию"
                          : "Произведение добавлено";
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
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
                    currentUserId: widget.currentUserId,
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
                        onFetchPlaybackStreamUrl: widget.onFetchPlaybackStreamUrl,
                        playbackError: widget.playbackError,
                        onLoadBookContent: widget.onLoadBookContent,
                        onMarkItemViewed: widget.onMarkItemViewed,
                        onFetchMediaFiles: widget.onFetchMediaFiles,
                        onBindMainMediaFile: widget.onBindMainMediaFile,
                        onUploadAndBindMainMediaFile:
                            widget.onUploadAndBindMainMediaFile,
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
