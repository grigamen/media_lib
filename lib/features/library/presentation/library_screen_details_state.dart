part of 'library_screen.dart';

class _MediaItemDetailsPageState extends State<_MediaItemDetailsPage> {
  late List<MediaListItem> _variants;
  bool _isLoadingLinked = false;
  final Set<String> _ownerMainFileSectionOpen = {};

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

  /// Rejected formats are hidden in the grouped work view unless the current
  /// user owns that media item (they may edit and resubmit).
  bool _shouldShowVariantInWorkGroup(MediaListItem item) {
    if (item.moderationStatus != "rejected") {
      return true;
    }
    final uid = widget.currentUserId;
    return uid != null && item.userId == uid;
  }

  bool _isFileCompatibleWithType({
    required String? filename,
    required String? mimeType,
    required String mediaType,
  }) {
    if (filename == null) {
      return true;
    }
    var normalizedMime = (mimeType ?? "").trim().toLowerCase();
    if (normalizedMime.isEmpty ||
        normalizedMime == "application/octet-stream" ||
        normalizedMime == "binary/octet-stream") {
      normalizedMime =
          (_inferContentTypeFromName(filename) ?? "").trim().toLowerCase();
    }
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
    if (lower.endsWith(".avi") || lower.endsWith(".avl")) {
      return "video/x-msvideo";
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _variants =
        List<MediaListItem>.from(
          widget.group.groupItems,
        ).where(_shouldShowVariantInWorkGroup).toList();
    _loadLinkedVariants();
  }

  Future<void> _loadLinkedVariants() async {
    setState(() {
      _isLoadingLinked = true;
    });

    final refreshedKnownVariants = <MediaListItem>[];
    for (final variant in _variants) {
      final fresh = await widget.onLoadItemById(variant.id);
      final item = fresh ?? variant;
      if (_shouldShowVariantInWorkGroup(item)) {
        refreshedKnownVariants.add(item);
      }
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
      if (linkedItem != null && _shouldShowVariantInWorkGroup(linkedItem)) {
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

  Future<void> _refreshVariant(String mediaItemId) async {
    final fresh = await widget.onLoadItemById(mediaItemId);
    if (!mounted || fresh == null) {
      return;
    }
    setState(() {
      final index = _variants.indexWhere((e) => e.id == mediaItemId);
      if (index >= 0) {
        _variants[index] = fresh;
      }
    });
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
    MediaUploadPayload? coverUpload;
    MediaUploadPayload? mainFileUpload;
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
                  coverUploadPayload: coverUpload,
                  uploadPayload: mainFileUpload,
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
                                        withData: kIsWeb,
                                      );
                                  if (!context.mounted ||
                                      result == null ||
                                      result.files.isEmpty) {
                                    return;
                                  }
                                  final file = result.files.first;
                                  final mime =
                                      _inferImageMimeFromFilename(file.name) ??
                                      "image/jpeg";
                                  final payload =
                                      MediaUploadPayload.tryFromPlatformFile(
                                        file: file,
                                        contentType: mime,
                                      );
                                  if (payload == null) {
                                    setDialogState(() {
                                      submitError =
                                          "Не удалось прочитать файл обложки";
                                    });
                                    return;
                                  }
                                  setDialogState(() {
                                    coverUpload = payload;
                                  });
                                },
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          coverUpload == null
                              ? "Обновить обложку"
                              : "Обложка: ${coverUpload!.filename}",
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
                                              "avi",
                                              "avl",
                                            ]
                                            : const <String>[
                                              "txt",
                                              "md",
                                              "pdf",
                                              "epub",
                                              "docx",
                                            ];
                                    final result = await pickMediaFileForUpload(
                                      context: context,
                                      allowedExtensions: allowedExtensions,
                                    );
                                    if (!context.mounted ||
                                        result == null ||
                                        result.files.isEmpty) {
                                      return;
                                    }
                                    final file = result.files.first;
                                    final mime =
                                        _inferContentTypeFromName(file.name) ??
                                        _fallbackContentType(item.type);
                                    final payload =
                                        MediaUploadPayload.tryFromPlatformFile(
                                          file: file,
                                          contentType: mime,
                                        );
                                    if (payload == null) {
                                      setDialogState(() {
                                        submitError =
                                            "Не удалось прочитать выбранный файл";
                                      });
                                      return;
                                    }
                                    setDialogState(() {
                                      mainFileUpload = payload;
                                      submitError = null;
                                    });
                                  },
                          icon: const Icon(Icons.attach_file_outlined),
                          label: Text(
                            mainFileUpload == null
                                ? "Заменить файл"
                                : "Файл: ${mainFileUpload!.filename}",
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
    final inheritedCoverUrl = () {
      for (final v in widget.group.groupItems) {
        final u = v.coverUrl?.trim();
        if (u != null && u.isNotEmpty) {
          return u;
        }
      }
      return null;
    }();
    final hasInheritedCover = inheritedCoverUrl != null;
    MediaUploadPayload? formatCoverUpload;
    MediaUploadPayload? formatMainUpload;
    String? genrePickerValue;
    String selectedType = "book";
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
              final mainUpload = formatMainUpload;
              if (mainUpload != null &&
                  !_isFileCompatibleWithType(
                    filename: mainUpload.filename,
                    mimeType: mainUpload.contentType,
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
              if (requiresUpload && formatMainUpload == null) {
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
                  coverUrl:
                      formatCoverUpload == null ? inheritedCoverUrl : null,
                  coverUploadPayload: formatCoverUpload,
                  description: descriptionController.text.trim(),
                  uploadPayload: formatMainUpload,
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
                                    formatMainUpload = null;
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
                      if (hasInheritedCover && formatCoverUpload == null) ...[
                        Text(
                          "Обложка будет такой же, как у текущего произведения.",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
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
                                            withData: kIsWeb,
                                          );
                                      if (!context.mounted ||
                                          result == null ||
                                          result.files.isEmpty) {
                                        return;
                                      }
                                      final file = result.files.first;
                                      final mime =
                                          _inferImageMimeFromFilename(
                                            file.name,
                                          ) ??
                                          "image/jpeg";
                                      final payload =
                                          MediaUploadPayload.tryFromPlatformFile(
                                            file: file,
                                            contentType: mime,
                                          );
                                      if (payload == null) {
                                        setDialogState(() {
                                          submitError =
                                              "Не удалось прочитать файл обложки";
                                        });
                                        return;
                                      }
                                      setDialogState(() {
                                        formatCoverUpload = payload;
                                        submitError = null;
                                      });
                                    },
                            child: const Text("Другая обложка…"),
                          ),
                        ),
                      ] else if (formatCoverUpload != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                "Обложка: ${formatCoverUpload!.filename}",
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            if (hasInheritedCover)
                              TextButton(
                                onPressed:
                                    isSubmitting
                                        ? null
                                        : () {
                                          setDialogState(() {
                                            formatCoverUpload = null;
                                          });
                                        },
                                child: const Text("Как у произведения"),
                              ),
                          ],
                        ),
                        if (!hasInheritedCover) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
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
                                              withData: kIsWeb,
                                            );
                                        if (!context.mounted ||
                                            result == null ||
                                            result.files.isEmpty) {
                                          return;
                                        }
                                        final file = result.files.first;
                                        final mime =
                                            _inferImageMimeFromFilename(
                                              file.name,
                                            ) ??
                                            "image/jpeg";
                                        final payload =
                                            MediaUploadPayload.tryFromPlatformFile(
                                              file: file,
                                              contentType: mime,
                                            );
                                        if (payload == null) {
                                          setDialogState(() {
                                            submitError =
                                                "Не удалось прочитать файл обложки";
                                          });
                                          return;
                                        }
                                        setDialogState(() {
                                          formatCoverUpload = payload;
                                          submitError = null;
                                        });
                                      },
                              icon: const Icon(Icons.image_outlined, size: 20),
                              label: const Text("Сменить файл"),
                            ),
                          ),
                        ],
                      ] else ...[
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
                                          withData: kIsWeb,
                                        );
                                    if (!context.mounted ||
                                        result == null ||
                                        result.files.isEmpty) {
                                      return;
                                    }
                                    final file = result.files.first;
                                    final mime =
                                        _inferImageMimeFromFilename(
                                          file.name,
                                        ) ??
                                        "image/jpeg";
                                    final payload =
                                        MediaUploadPayload.tryFromPlatformFile(
                                          file: file,
                                          contentType: mime,
                                        );
                                    if (payload == null) {
                                      setDialogState(() {
                                        submitError =
                                            "Не удалось прочитать файл обложки";
                                      });
                                      return;
                                    }
                                    setDialogState(() {
                                      formatCoverUpload = payload;
                                    });
                                  },
                          icon: const Icon(Icons.image_outlined),
                          label: const Text("Выбрать обложку (опционально)"),
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
                                              "avi",
                                              "avl",
                                            ]
                                            : const <String>[
                                              "txt",
                                              "md",
                                              "pdf",
                                              "epub",
                                              "docx",
                                            ];
                                    final result = await pickMediaFileForUpload(
                                      context: context,
                                      allowedExtensions: allowedExtensions,
                                    );
                                    if (!context.mounted ||
                                        result == null ||
                                        result.files.isEmpty) {
                                      return;
                                    }
                                    final file = result.files.first;
                                    final mime =
                                        _inferContentTypeFromName(file.name) ??
                                        _fallbackContentType(selectedType);
                                    final payload =
                                        MediaUploadPayload.tryFromPlatformFile(
                                          file: file,
                                          contentType: mime,
                                        );
                                    if (payload == null) {
                                      setDialogState(() {
                                        submitError =
                                            "Не удалось прочитать выбранный файл";
                                      });
                                      return;
                                    }
                                    setDialogState(() {
                                      formatMainUpload = payload;
                                    });
                                  },
                          icon: const Icon(Icons.attach_file),
                          label: Text(
                            formatMainUpload == null
                                ? "Выбрать файл"
                                : "Файл: ${formatMainUpload!.filename}",
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

  Widget _workDetailsHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: "Назад",
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(child: Text(title, style: theme.textTheme.headlineSmall)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.group.displayTitle;
    if (_variants.isEmpty) {
      return Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _workDetailsHeader(context, title),
            const Expanded(
              child: Center(child: Text("Нет доступных форм произведения")),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _workDetailsHeader(context, title),
          Expanded(
            child: DefaultTabController(
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
                      final activeGenres = _uniqueGenres([
                        ...?activeItem.genres,
                      ]);

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
                                                        Icons
                                                            .broken_image_outlined,
                                                      ),
                                                    ),
                                                  ),
                                            )
                                            : Container(
                                              color: Colors.black12,
                                              child: const Center(
                                                child: Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activeItem.title,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.headlineSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(activeAuthor),
                                      if (activeGenres.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: activeGenres
                                              .map(
                                                (genre) =>
                                                    Chip(label: Text(genre)),
                                              )
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
                                .map(
                                  (item) => Tab(text: _labelForType(item.type)),
                                )
                                .toList(growable: false),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: _variants
                                  .map(
                                    (item) => ListView(
                                      key: ValueKey<String>(item.id),
                                      padding: const EdgeInsets.all(16),
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            color:
                                                Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerLow,
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
                                                  item
                                                              .description
                                                              ?.isNotEmpty ==
                                                          true
                                                      ? item.description!
                                                      : "Описание отсутствует",
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (widget.currentUserId != null &&
                                            item.userId ==
                                                widget.currentUserId &&
                                            !item.id.startsWith("demo-")) ...[
                                          const SizedBox(height: 16),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                if (_ownerMainFileSectionOpen
                                                    .contains(item.id)) {
                                                  _ownerMainFileSectionOpen
                                                      .remove(item.id);
                                                } else {
                                                  _ownerMainFileSectionOpen.add(
                                                    item.id,
                                                  );
                                                }
                                              });
                                            },
                                            icon: Icon(
                                              _ownerMainFileSectionOpen
                                                      .contains(item.id)
                                                  ? Icons.expand_less
                                                  : Icons.folder_open_outlined,
                                            ),
                                            label: Text(
                                              _ownerMainFileSectionOpen
                                                      .contains(item.id)
                                                  ? "Скрыть основной файл контента"
                                                  : "Основной файл контента",
                                            ),
                                          ),
                                          if (_ownerMainFileSectionOpen
                                              .contains(item.id)) ...[
                                            const SizedBox(height: 12),
                                            _OwnerMainMediaFileCard(
                                              item: item,
                                              onFetchFiles:
                                                  widget.onFetchMediaFiles,
                                              onBindFile:
                                                  widget.onBindMainMediaFile,
                                              onUploadAndBind:
                                                  widget
                                                      .onUploadAndBindMainMediaFile,
                                              onVariantRefreshed:
                                                  () =>
                                                      _refreshVariant(item.id),
                                              fallbackContentType:
                                                  _fallbackContentType,
                                              inferContentTypeFromName:
                                                  _inferContentTypeFromName,
                                              isFileCompatibleWithType:
                                                  _isFileCompatibleWithType,
                                            ),
                                          ],
                                        ],
                                        if (item.type == "book") ...[
                                          const SizedBox(height: 16),
                                          _BookContentPanel(
                                            item: item,
                                            onLoadBookContent:
                                                widget.onLoadBookContent,
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            if (widget.currentUserId != null &&
                                                item.userId ==
                                                    widget.currentUserId)
                                              OutlinedButton.icon(
                                                onPressed:
                                                    () =>
                                                        _showEditVariantDialog(
                                                          item,
                                                        ),
                                                icon: const Icon(Icons.edit),
                                                label: const Text(
                                                  "Редактировать",
                                                ),
                                              ),
                                            FilledButton.icon(
                                              onPressed: _showAddFormatDialog,
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                              ),
                                              label: const Text(
                                                "Добавить формат",
                                              ),
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
                                                widget
                                                    .onPlaybackProgressChanged,
                                            onPausePlaybackSession:
                                                widget.onPausePlaybackSession,
                                            onCompletePlaybackSession:
                                                widget
                                                    .onCompletePlaybackSession,
                                            onFlushPlaybackSession:
                                                widget.onFlushPlaybackSession,
                                            onEndPlaybackSession:
                                                widget.onEndPlaybackSession,
                                            playbackSpeed: widget.playbackSpeed,
                                            onSetPlaybackSpeed:
                                                widget.onSetPlaybackSpeed,
                                            pendingPlaybackSync:
                                                widget.pendingPlaybackSync,
                                            onFetchPlaybackStreamUrl:
                                                widget.onFetchPlaybackStreamUrl,
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
          ),
        ],
      ),
    );
  }
}
