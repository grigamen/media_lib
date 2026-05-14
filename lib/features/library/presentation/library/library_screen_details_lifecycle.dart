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
    }
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
