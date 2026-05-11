import "package:sqflite/sqflite.dart";

class ProgressMirrorRow {
  const ProgressMirrorRow({
    required this.mediaItemId,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.isCompleted,
    required this.pendingSync,
    required this.updatedAtLocalMs,
  });

  final String mediaItemId;
  final int positionSeconds;
  final int? durationSeconds;
  final bool isCompleted;
  final bool pendingSync;
  final int updatedAtLocalMs;
}

class LocalProgressRow {
  const LocalProgressRow({
    required this.mediaItemId,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.isCompleted,
  });

  final String mediaItemId;
  final int positionSeconds;
  final int? durationSeconds;
  final bool isCompleted;
}

class ProgressLocalStore {
  ProgressLocalStore(this._db);

  final Database _db;

  Future<void> upsertMirror({
    required String userId,
    required String mediaItemId,
    required int positionSeconds,
    required int? durationSeconds,
    required bool isCompleted,
    required bool pendingSync,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert("progress_local", <String, Object?>{
      "user_id": userId,
      "media_item_id": mediaItemId,
      "position_seconds": positionSeconds,
      "duration_seconds": durationSeconds,
      "is_completed": isCompleted ? 1 : 0,
      "updated_at_local_ms": now,
      "pending_sync": pendingSync ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ProgressMirrorRow?> loadMirror({
    required String userId,
    required String mediaItemId,
  }) async {
    final rows = await _db.query(
      "progress_local",
      where: "user_id = ? AND media_item_id = ?",
      whereArgs: <Object?>[userId, mediaItemId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final r = rows.single;
    return ProgressMirrorRow(
      mediaItemId: r["media_item_id"]! as String,
      positionSeconds: r["position_seconds"]! as int,
      durationSeconds: r["duration_seconds"] as int?,
      isCompleted: (r["is_completed"] as int) != 0,
      pendingSync: (r["pending_sync"] as int) != 0,
      updatedAtLocalMs: r["updated_at_local_ms"]! as int,
    );
  }

  Future<List<LocalProgressRow>> listPending(String userId) async {
    final rows = await _db.query(
      "progress_local",
      where: "user_id = ? AND pending_sync = 1",
      whereArgs: <Object?>[userId],
    );
    return rows
        .map(
          (r) => LocalProgressRow(
            mediaItemId: r["media_item_id"]! as String,
            positionSeconds: r["position_seconds"]! as int,
            durationSeconds: r["duration_seconds"] as int?,
            isCompleted: (r["is_completed"] as int) != 0,
          ),
        )
        .toList(growable: false);
  }

  Future<void> clearForUser(String userId) async {
    await _db.delete(
      "progress_local",
      where: "user_id = ?",
      whereArgs: <Object?>[userId],
    );
  }
}
