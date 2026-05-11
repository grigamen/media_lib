import "package:path/path.dart" as p;
import "package:sqflite/sqflite.dart";

/// SQLite-персистентность для кэша каталога и локального прогресса (неделя 8).
class MediaLibDatabase {
  MediaLibDatabase._();

  static Database? _db;
  static const _fileName = "media_lib.sqlite";
  static const _version = 2;

  static Future<Database> open() async {
    if (_db != null) {
      return _db!;
    }
    final dir = await getDatabasesPath();
    final path = p.join(dir, _fileName);
    _db = await openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute("""
CREATE TABLE catalog_cache (
  cache_key TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  items_json TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL
)""");
        await db.execute("""
CREATE TABLE progress_local (
  user_id TEXT NOT NULL,
  media_item_id TEXT NOT NULL,
  position_seconds INTEGER NOT NULL,
  duration_seconds INTEGER,
  is_completed INTEGER NOT NULL,
  updated_at_local_ms INTEGER NOT NULL,
  pending_sync INTEGER NOT NULL,
  PRIMARY KEY (user_id, media_item_id)
)""");
        await db.execute("""
CREATE TABLE recently_viewed_local (
  user_id TEXT PRIMARY KEY,
  item_ids_json TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL
)""");
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("""
CREATE TABLE IF NOT EXISTS recently_viewed_local (
  user_id TEXT PRIMARY KEY,
  item_ids_json TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL
)""");
        }
      },
    );
    return _db!;
  }

  /// Сброс singleton и удаление файла БД (только для тестов).
  static Future<void> disposeForTests() async {
    await _db?.close();
    _db = null;
    try {
      final dir = await getDatabasesPath();
      final path = p.join(dir, _fileName);
      await deleteDatabase(path);
    } catch (_) {}
  }
}
