part of "add_item_screen.dart";

// Сабмит формы и выбор файлов контента/обложки с проверкой MIME и расширений.

/// Валидация и действия [AddItemScreen]: сабмит формы и пикеры файлов.
mixin _AddItemScreenLogic on _AddItemScreenFields {
  /// Проверяет обязательные файлы, создаёт запись через API и сбрасывает поля при успехе.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      if (_selectedFileName != null &&
          !_isFileCompatibleWithType(
            filename: _selectedFileName,
            mimeType: _selectedFileMime,
            mediaType: _selectedType,
          )) {
        setState(() {
          _error = "Выбранный файл не подходит для типа $_selectedType";
          _isSubmitting = false;
        });
        return;
      }
      final requiresUpload =
          _selectedType == "audiobook" || _selectedType == "video";
      if (requiresUpload &&
          (_selectedFileName == null || _selectedFileUpload == null)) {
        setState(() {
          _error = "Для аудиокниги и видео нужно выбрать файл";
          _isSubmitting = false;
        });
        return;
      }
      MediaAuthor? authorToSave = _selectedAuthor;
      final draftName = _authorQuery.trim();
      if (authorToSave == null && draftName.isNotEmpty) {
        authorToSave = await widget.onCreateAuthor(draftName);
      }
      final created = await widget.onAddItem(
        type: _selectedType,
        title: _titleController.text.trim(),
        authorId: authorToSave?.id,
        author: authorToSave?.name,
        genres: _selectedGenres.isEmpty ? null : _selectedGenres,
        coverUploadPayload: _selectedCoverUpload,
        uploadPayload:
            _selectedFileName != null && _selectedFileUpload != null
                ? _selectedFileUpload
                : null,
      );
      if (!mounted) {
        return;
      }
      _titleController.clear();
      _selectedAuthor = null;
      _authorQuery = "";
      _selectedFileName = null;
      _selectedFileMime = null;
      _selectedFileUpload = null;
      _selectedCoverUpload = null;
      _selectedGenres = [];
      _genrePickerValue = null;
      final msg =
          created?.moderationStatus == "pending"
              ? "Произведение отправлено на модерацию"
              : "Произведение добавлено";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _error = "Не удалось добавить произведение";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Диалог выбора основного файла в зависимости от выбранного типа контента.
  Future<void> _pickFile() async {
    if (_isSubmitting || _isPickingFile) {
      return;
    }
    _isPickingFile = true;
    final allowedExtensions =
        _selectedType == "audiobook"
            ? const ["mp3", "m4a", "aac", "wav", "ogg"]
            : _selectedType == "video"
            ? const ["mp4", "mkv", "webm", "mov", "avi", "avl"]
            : const ["txt", "md", "pdf", "epub", "docx"];
    try {
      final result = await pickMediaFileForUpload(
        context: context,
        allowedExtensions: allowedExtensions,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.first;
      final inferred =
          _inferContentTypeFromName(file.name) ??
          _fallbackContentType(_selectedType);
      final payload = MediaUploadPayload.tryFromPlatformFile(
        file: file,
        contentType: inferred,
      );
      if (payload == null) {
        setState(() {
          _error = "Не удалось прочитать выбранный файл";
        });
        return;
      }
      setState(() {
        _selectedFileName = file.name;
        _selectedFileMime = inferred;
        _selectedFileUpload = payload;
        _error = null;
      });
    } finally {
      _isPickingFile = false;
    }
  }

  /// Выбор изображения обложки (jpg/png/webp) и сборка [MediaUploadPayload].
  Future<void> _pickCoverFile() async {
    if (_isSubmitting || _isPickingCover) {
      return;
    }
    _isPickingCover = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ["jpg", "jpeg", "png", "webp"],
        withData: kIsWeb,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.first;
      final mime = _inferImageContentTypeFromName(file.name) ?? "image/jpeg";
      final payload = MediaUploadPayload.tryFromPlatformFile(
        file: file,
        contentType: mime,
      );
      if (payload == null) {
        setState(() {
          _error = "Не удалось прочитать файл обложки";
        });
        return;
      }
      setState(() {
        _selectedCoverUpload = payload;
        _error = null;
      });
    } finally {
      _isPickingCover = false;
    }
  }

  /// MIME по умолчанию, если платформа не дала тип при пике файла.
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

  /// Сопоставляет расширение/MIME с выбранным типом произведения.
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

  /// Эвристика MIME по имени файла для книг и медиаконтента.
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

  /// Угадывание image/* по расширению для обложки.
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
}
