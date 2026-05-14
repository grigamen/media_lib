part of 'library_screen.dart';

// Окно «изменить этот вариант»: название, автор, жанры, новая обложка или файл — затем отправка на сервер.

/// Набор методов с окном редактирования для автора записи.
mixin _MediaItemDetailsEditDialogsMixin on _MediaItemDetailsLifecycleMixin {
  /// Показываем форму, по «Сохранить» уходим на сервер и подменяем карточку в списке вкладок.
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
}
