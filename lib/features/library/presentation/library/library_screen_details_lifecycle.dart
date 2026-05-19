part of 'library_screen.dart';

// Проверки файлов и догрузка «соседних» форматов с сервера, чтобы все варианты одного произведения были под рукой.

/// Набор проверок и загрузок для карточки: подтянуть связанные записи, понять тип файла, обновить один вариант.
mixin _MediaItemDetailsLifecycleMixin on _MediaItemDetailsStateFields {
  /// Если настоящий тип файла неизвестен — подставляем разумный вариант по виду контента (книга / звук / видео).
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

  /// В общем списке прячем отклонённые модерацией варианты, но автор своей записи всё равно видит её — чтобы мог исправить.
  bool _shouldShowVariantInWorkGroup(MediaListItem item) {
    if (item.moderationStatus != "rejected") {
      return true;
    }
    final uid = widget.currentUserId;
    return uid != null && item.userId == uid;
  }

  /// Проверяем: выбранный файл вообще подходит под книгу, звук или ролик (по расширению и служебному типу файла).
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

  /// По имени файла пытаемся понять, что это за формат — чтобы проверить, можно ли так загружать.
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

  /// Обновляем список вкладок с сервера и подгружаем связанные части того же произведения, чтобы ничего не потерялось.
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
      _syncTabControllerToFocusedVariant();
    }
  }

  Future<PlaybackSessionOutcome> _beginPlaybackSessionForVariant(
    MediaListItem item,
  ) async {
    final outcome = await widget.onBeginPlaybackSession(item);
    if (mounted && outcome.config != null) {
      await _refreshVariant(item.id);
    }
    return outcome;
  }

  Future<void> _pickAuthorBookLocalFile(MediaListItem item) async {
    final save = widget.onSaveAuthorBookLocalFile;
    if (save == null) {
      return;
    }
    final result = await pickMediaFileForUpload(
      context: context,
      allowedExtensions: const ["txt", "md", "docx"],
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.single;
    final name = file.name.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось прочитать файл")),
      );
      return;
    }
    final mime =
        _inferContentTypeFromName(name) ?? _fallbackContentType("book");
    if (!_isFileCompatibleWithType(
      filename: name,
      mimeType: mime,
      mediaType: "book",
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Выберите файл книги (txt, md, docx)")),
      );
      return;
    }
    final payload = MediaUploadPayload.tryFromPlatformFile(
      file: file,
      contentType: mime,
    );
    if (payload == null || payload.filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "На этой платформе нужен путь к файлу на устройстве",
          ),
        ),
      );
      return;
    }
    final resolvedMime = MediaUploadPayload.resolvedMainFileContentType(
      filename: payload.filename,
      declaredContentType: payload.contentType,
      mediaItemType: "book",
    );
    await save(
      mediaItemId: item.id,
      filePath: payload.filePath!,
      filename: payload.filename,
      contentType: resolvedMime,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Файл на устройстве привязан для чтения")),
    );
  }

  Future<void> _openBookReader(MediaListItem item) async {
    await widget.onRecordMediaItemView(item.id);
    if (!mounted) {
      return;
    }
    await _refreshVariant(item.id);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => BookReaderScreen(
              item: item,
              onLoadBookContent: widget.onLoadBookContent,
            ),
      ),
    );
  }

  /// После сохранения или смены файла подставляем свежую карточку вместо старой в списке вкладок.
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
}
