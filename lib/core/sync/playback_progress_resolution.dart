import "package:media_lib/core/local/progress_local_store.dart";

/// Last-write-wins по времени обновления: локально `updated_at_local_ms`, с сервера `updated_at` (UTC ms).
///
/// При равных метках времени и `pending_sync` у локальной копии выбираем локальную (нет гарантии, что
/// последний успешный PUT отразился на сервере).
class PlaybackProgressResolution {
  const PlaybackProgressResolution({
    required this.positionSeconds,
    required this.durationSeconds,
    required this.isCompleted,
    required this.needsPushToServer,
  });

  final int positionSeconds;
  final int? durationSeconds;
  final bool isCompleted;

  /// Локальный снимок новее серверного — нужно отдать [positionSeconds] на PUT.
  final bool needsPushToServer;

  /// `serverUpdatedAtUtcMs` — распарсенный из API `updated_at`; `null`, если сервер не прислал поле.
  static PlaybackProgressResolution resolve({
    required int serverPositionSeconds,
    required int? serverDurationSeconds,
    required bool serverIsCompleted,
    required int? serverUpdatedAtUtcMs,
    ProgressMirrorRow? local,
  }) {
    final serverMs = serverUpdatedAtUtcMs ?? 0;
    if (local == null) {
      return PlaybackProgressResolution(
        positionSeconds: serverPositionSeconds,
        durationSeconds: serverDurationSeconds,
        isCompleted: serverIsCompleted,
        needsPushToServer: false,
      );
    }
    final preferLocal =
        local.updatedAtLocalMs > serverMs ||
        (local.updatedAtLocalMs == serverMs && local.pendingSync);
    if (!preferLocal) {
      return PlaybackProgressResolution(
        positionSeconds: serverPositionSeconds,
        durationSeconds: serverDurationSeconds,
        isCompleted: serverIsCompleted,
        needsPushToServer: false,
      );
    }
    return PlaybackProgressResolution(
      positionSeconds: local.positionSeconds,
      durationSeconds: local.durationSeconds,
      isCompleted: local.isCompleted,
      needsPushToServer: true,
    );
  }
}
