import "package:file_picker/file_picker.dart";
import "package:flutter/foundation.dart";

class MediaUploadPayload {
  const MediaUploadPayload._({
    required this.filename,
    required this.contentType,
    required this.byteLength,
    this.bytes,
    this.filePath,
  }) : assert((bytes != null) ^ (filePath != null));

  factory MediaUploadPayload.fromBytes({
    required String filename,
    required String contentType,
    required Uint8List bytes,
  }) {
    return MediaUploadPayload._(
      filename: filename,
      contentType: contentType,
      byteLength: bytes.length,
      bytes: bytes,
      filePath: null,
    );
  }

  factory MediaUploadPayload.fromFilePath({
    required String filename,
    required String contentType,
    required String filePath,
    required int byteLength,
  }) {
    return MediaUploadPayload._(
      filename: filename,
      contentType: contentType,
      byteLength: byteLength,
      bytes: null,
      filePath: filePath,
    );
  }

  /// Без загрузки файла в RAM: на мобильных [PlatformFile.path] + [PlatformFile.size];
  /// на веб — только [PlatformFile.bytes].
  static MediaUploadPayload? tryFromPlatformFile({
    required PlatformFile file,
    required String contentType,
  }) {
    if (file.name.trim().isEmpty) {
      return null;
    }
    if (kIsWeb) {
      final data = file.bytes;
      if (data == null || data.isEmpty) {
        return null;
      }
      return MediaUploadPayload.fromBytes(
        filename: file.name,
        contentType: contentType,
        bytes: data,
      );
    }
    final path = file.path;
    if (path != null && path.isNotEmpty && file.size > 0) {
      return MediaUploadPayload.fromFilePath(
        filename: file.name,
        contentType: contentType,
        filePath: path,
        byteLength: file.size,
      );
    }
    final data = file.bytes;
    if (data != null && data.isNotEmpty) {
      return MediaUploadPayload.fromBytes(
        filename: file.name,
        contentType: contentType,
        bytes: data,
      );
    }
    return null;
  }

  static String? inferMainFileContentTypeFromFilename(String filename) {
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

  static String? inferCoverContentTypeFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
      return "image/jpeg";
    }
    if (lower.endsWith(".png")) return "image/png";
    if (lower.endsWith(".webp")) return "image/webp";
    return null;
  }

  static String _fallbackMainFileContentTypeForMediaKind(String kind) {
    switch (kind) {
      case "book":
        return "text/plain";
      case "audiobook":
        return "audio/mpeg";
      case "video":
        return "video/mp4";
      default:
        return "application/octet-stream";
    }
  }

  /// Many mobile pickers report [application/octet-stream] for uncommon video
  /// extensions (e.g. `.avl`). The API needs a concrete allowed MIME type.
  static String resolvedMainFileContentType({
    required String filename,
    required String declaredContentType,
    required String mediaItemType,
  }) {
    final inferred = inferMainFileContentTypeFromFilename(filename);
    // OS MIME is often wrong or not in the API allowlist (e.g. video/avi,
    // application/octet-stream). Prefer extension-based type when known.
    if (inferred != null && inferred.isNotEmpty) {
      return inferred;
    }
    final d = declaredContentType.trim();
    final low = d.toLowerCase();
    if (low.isEmpty ||
        low == "application/octet-stream" ||
        low == "binary/octet-stream") {
      return _fallbackMainFileContentTypeForMediaKind(mediaItemType);
    }
    return d;
  }

  static String resolvedCoverContentType({
    required String filename,
    required String declaredContentType,
  }) {
    final inferred = inferCoverContentTypeFromFilename(filename);
    final d = declaredContentType.trim();
    final low = d.toLowerCase();
    if (low.isEmpty ||
        low == "application/octet-stream" ||
        low == "binary/octet-stream") {
      return inferred ?? "image/jpeg";
    }
    return d;
  }

  final String filename;
  final String contentType;
  final int byteLength;
  final Uint8List? bytes;
  final String? filePath;
}
