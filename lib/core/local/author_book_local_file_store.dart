import "package:sqflite/sqflite.dart";

/// Локальный путь к файлу книги автора (чтение без загрузки с сервера).
class AuthorBookLocalSource {
  const AuthorBookLocalSource({
    required this.filePath,
    required this.filename,
    required this.contentType,
  });

  final String filePath;
  final String filename;
  final String contentType;
}

/// SQLite: путь к файлу книги на устройстве автора (user_id + media_item_id).
class AuthorBookLocalFileStore {
  AuthorBookLocalFileStore(this._db);

  final Database _db;

  Future<AuthorBookLocalSource?> load({
    required String userId,
    required String mediaItemId,
  }) async {
    final rows = await _db.query(
      "author_book_local_file",
      columns: ["file_path", "filename", "content_type"],
      where: "user_id = ? AND media_item_id = ?",
      whereArgs: <Object?>[userId, mediaItemId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    final path = row["file_path"];
    final filename = row["filename"];
    final contentType = row["content_type"];
    if (path is! String ||
        path.isEmpty ||
        filename is! String ||
        filename.isEmpty ||
        contentType is! String ||
        contentType.isEmpty) {
      return null;
    }
    return AuthorBookLocalSource(
      filePath: path,
      filename: filename,
      contentType: contentType,
    );
  }

  Future<void> save({
    required String userId,
    required String mediaItemId,
    required String filePath,
    required String filename,
    required String contentType,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert(
      "author_book_local_file",
      <String, Object?>{
        "user_id": userId,
        "media_item_id": mediaItemId,
        "file_path": filePath,
        "filename": filename,
        "content_type": contentType,
        "updated_at_ms": now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearForUser(String userId) async {
    await _db.delete(
      "author_book_local_file",
      where: "user_id = ?",
      whereArgs: <Object?>[userId],
    );
  }

  Future<void> deleteForItem({
    required String userId,
    required String mediaItemId,
  }) async {
    await _db.delete(
      "author_book_local_file",
      where: "user_id = ? AND media_item_id = ?",
      whereArgs: <Object?>[userId, mediaItemId],
    );
  }
}
