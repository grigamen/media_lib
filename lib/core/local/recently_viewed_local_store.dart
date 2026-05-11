import "dart:convert";

import "package:sqflite/sqflite.dart";

class RecentlyViewedLocalStore {
  RecentlyViewedLocalStore(this._db);

  final Database _db;

  Future<List<String>?> loadItemIds(String userId) async {
    final rows = await _db.query(
      "recently_viewed_local",
      columns: ["item_ids_json"],
      where: "user_id = ?",
      whereArgs: <Object?>[userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final raw = rows.first["item_ids_json"];
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return null;
    }
    return decoded
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> saveItemIds(String userId, List<String> itemIds) async {
    final encoded = jsonEncode(itemIds);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert("recently_viewed_local", <String, Object?>{
      "user_id": userId,
      "item_ids_json": encoded,
      "updated_at_ms": now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearForUser(String userId) async {
    await _db.delete(
      "recently_viewed_local",
      where: "user_id = ?",
      whereArgs: <Object?>[userId],
    );
  }
}
