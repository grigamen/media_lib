part of 'library_screen.dart';

// Окно «добавить ещё один формат» к тому же произведению: тип, поля, при необходимости файл — проверяем, что формат ещё не был.

/// Набор методов с окном добавления формата (книга / аудио / видео).
mixin _MediaItemDetailsAddFormatDialogsMixin
    on _MediaItemDetailsLifecycleMixin {
  /// Создаём новую запись на сервере и добавляем её в список вкладок на экране.
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
}
