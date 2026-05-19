import "dart:convert";

import "package:archive/archive.dart";
import "package:enough_convert/enough_convert.dart";
import "package:http/http.dart" as http;

import "../../core/local/author_book_local_file_store.dart";
import "../../core/network/api_client.dart";
import "../../features/auth/data/auth_repository.dart";
import "../../features/library/data/library_repository.dart";
import "book_file_reader_stub.dart"
    if (dart.library.io) "book_file_reader_io.dart";

/// Загрузка и разбор текста книги (plain text / DOCX) для встроенного читателя.
final class BookContentLoader {
  BookContentLoader(this._library);

  final LibraryRepository _library;

  Future<String> loadPlainTextForReading({
    required MediaListItem item,
    required AuthSession? session,
    Future<AuthorBookLocalSource?> Function(MediaListItem item)?
    resolveLocalSource,
  }) async {
    if (item.type != "book") {
      throw ApiException("Этот формат не поддерживает чтение текста");
    }
    final localSource = await resolveLocalSource?.call(item);
    if (localSource != null) {
      return _loadPlainTextFromLocalSource(localSource);
    }
    if (item.id.startsWith("demo-")) {
      final fallback = item.description?.trim();
      if (fallback != null && fallback.isNotEmpty) {
        return fallback;
      }
      return "Для демо-книги текстовый контент не загружен.";
    }
    if (session == null) {
      throw ApiException("Сессия авторизации не найдена");
    }

    final detailedItem = await _library.fetchMediaItemById(
      accessToken: session.accessToken,
      mediaItemId: item.id,
    );
    final mediaFileId = item.mediaFileId ?? detailedItem.mediaFileId;
    if (mediaFileId == null || mediaFileId.isEmpty) {
      throw ApiException("Для книги не указан media_file_id в metadata_json.");
    }

    final streamInfo = await _library.fetchMediaStreamUrl(
      accessToken: session.accessToken,
      fileId: mediaFileId,
    );
    final response = await http
        .get(Uri.parse(streamInfo.streamUrl))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        "Не удалось загрузить содержимое книги (HTTP ${response.statusCode}).",
      );
    }

    final contentType = (response.headers["content-type"] ?? "").toLowerCase();
    if (contentType.contains("application/pdf") ||
        contentType.contains("application/epub+zip")) {
      throw ApiException(
        "Этот формат книги пока не поддерживается для встроенного чтения.",
      );
    }

    return parseBookBytesToPlainText(
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }

  Future<String> _loadPlainTextFromLocalSource(
    AuthorBookLocalSource source,
  ) async {
    final bytes = await readLocalBookFileBytes(source.filePath);
    if (bytes == null || bytes.isEmpty) {
      throw ApiException(
        "Локальный файл книги не найден на устройстве. Укажите файл снова.",
      );
    }
    return parseBookBytesToPlainText(
      bytes: bytes,
      contentType: source.contentType,
      filename: source.filename,
    );
  }
}

/// Разбор байтов книги (txt / md / docx) в текст для читалки.
String parseBookBytesToPlainText({
  required List<int> bytes,
  required String contentType,
  String? filename,
}) {
  final normalizedType = contentType.toLowerCase();
  final lowerName = (filename ?? "").toLowerCase();
  if (normalizedType.contains("application/pdf") ||
      normalizedType.contains("application/epub+zip") ||
      lowerName.endsWith(".pdf") ||
      lowerName.endsWith(".epub")) {
    throw ApiException(
      "Этот формат книги пока не поддерживается для встроенного чтения.",
    );
  }

  final looksLikeDocx =
      normalizedType.contains(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      ) ||
      lowerName.endsWith(".docx") ||
      _looksLikeZip(bytes);
  final String text;
  if (looksLikeDocx) {
    text = _extractDocxText(bytes).trim();
  } else {
    text = _decodePlainTextBytes(bytes).trim();
  }
  if (text.isEmpty) {
    throw ApiException("Файл книги пустой или не содержит читаемого текста.");
  }
  return text;
}

bool _looksLikeZip(List<int> bytes) {
  if (bytes.length < 2) {
    return false;
  }
  return bytes[0] == 0x50 && bytes[1] == 0x4b;
}

/// Picks UTF-8 when valid; otherwise scores common legacy byte encodings so
/// Russian / European `.txt` files are readable instead of showing `�`.
String _decodePlainTextBytes(List<int> rawBytes) {
  var bytes = rawBytes;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    bytes = bytes.sublist(3);
  }

  try {
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    // Not valid UTF-8; try permissive UTF-8 and single-byte legacy encodings.
  }

  final looseUtf8 = utf8.decode(bytes, allowMalformed: true);
  final lenChars = looseUtf8.runes.length;
  final fffdCount = looseUtf8.runes.where((r) => r == 0xFFFD).length;
  if (lenChars == 0 || (fffdCount * 200 <= lenChars)) {
    return looseUtf8;
  }

  final candidates = <String>[
    looseUtf8,
    const Windows1251Codec().decode(bytes),
    const Windows1252Codec().decode(bytes),
    latin1.decode(bytes),
  ];

  String best = candidates.first;
  var bestScore = _plainTextEncodingScore(best);
  for (var i = 1; i < candidates.length; i++) {
    final s = _plainTextEncodingScore(candidates[i]);
    if (s > bestScore) {
      bestScore = s;
      best = candidates[i];
    }
  }
  return best;
}

int _plainTextEncodingScore(String s) {
  if (s.isEmpty) {
    return 0;
  }
  var score = 0;
  for (final r in s.runes) {
    if (r == 0xFFFD) {
      score -= 500;
    } else if (r == 0x0A || r == 0x0D || r == 0x09) {
      score += 2;
    } else if (r < 0x20) {
      score -= 8;
    } else {
      score += 2;
    }
  }
  return score;
}

String _extractDocxText(List<int> bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    ArchiveFile? documentXmlFile;
    for (final file in archive.files) {
      if (file.name == "word/document.xml") {
        documentXmlFile = file;
        break;
      }
    }
    if (documentXmlFile == null) {
      throw ApiException("DOCX не содержит word/document.xml");
    }
    final xmlBytes = documentXmlFile.content;
    final xml = utf8.decode(xmlBytes, allowMalformed: true);
    final normalized = xml
        .replaceAll(RegExp(r"<w:tab\s*/>"), "\t")
        .replaceAll(RegExp(r"<w:br\s*/>"), "\n")
        .replaceAll(RegExp(r"</w:p>"), "\n")
        .replaceAll(RegExp(r"<w:p[^>]*>"), "")
        .replaceAll(RegExp(r"</?w:[^>]+>"), "");
    final unescaped = _decodeXmlEntities(normalized);
    return unescaped
        .replaceAll(RegExp(r"\n{3,}"), "\n\n")
        .replaceAll(RegExp(r"[ \t]{2,}"), " ")
        .trim();
  } on ApiException {
    rethrow;
  } catch (_) {
    throw ApiException("Не удалось распарсить DOCX-книгу");
  }
}

String _decodeXmlEntities(String text) {
  return text
      .replaceAll("&amp;", "&")
      .replaceAll("&lt;", "<")
      .replaceAll("&gt;", ">")
      .replaceAll("&quot;", '"')
      .replaceAll("&apos;", "'");
}
