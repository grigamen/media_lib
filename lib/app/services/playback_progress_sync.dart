import "dart:async";

import "../../core/local/progress_local_store.dart";
import "../../core/network/api_client.dart";
import "../../features/auth/data/auth_repository.dart";
import "../../features/library/data/library_repository.dart";

/// Периодический таймер синхронизации прогресса с сервером.
final class PlaybackProgressSyncTimer {
  PlaybackProgressSyncTimer({this.interval = const Duration(seconds: 10)});

  final Duration interval;
  Timer? _timer;

  void start(Future<void> Function() onTick) {
    _timer ??= Timer.periodic(interval, (_) {
      unawaited(onTick());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Отправка текущего прогресса на сервер и зеркало в [ProgressLocalStore].
final class PlaybackProgressPusher {
  PlaybackProgressPusher(this._library);

  final LibraryRepository _library;

  Future<void> pushOrMirrorPending({
    required AuthSession session,
    required String mediaItemId,
    required String? userId,
    required ProgressLocalStore? progressStore,
    required int positionSeconds,
    required int? durationSeconds,
    required bool isCompleted,
    required bool force,
    required bool hasUnsyncedProgress,
    required void Function(MediaProgress applied) onServerAccepted,
    required void Function(String userVisibleError) onTransientFailure,
  }) async {
    if (!force && !hasUnsyncedProgress) {
      return;
    }
    try {
      final progress = await _library.upsertMediaProgress(
        accessToken: session.accessToken,
        mediaItemId: mediaItemId,
        positionSeconds: positionSeconds,
        durationSeconds: durationSeconds,
        isCompleted: isCompleted,
      );
      if (userId != null && progressStore != null) {
        unawaited(
          progressStore.upsertMirror(
            userId: userId,
            mediaItemId: mediaItemId,
            positionSeconds: progress.positionSeconds,
            durationSeconds: progress.durationSeconds,
            isCompleted: progress.isCompleted,
            pendingSync: false,
          ),
        );
      }
      onServerAccepted(progress);
    } on ApiException catch (e) {
      if (userId != null && progressStore != null) {
        unawaited(
          progressStore.upsertMirror(
            userId: userId,
            mediaItemId: mediaItemId,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            isCompleted: isCompleted,
            pendingSync: true,
          ),
        );
      }
      onTransientFailure(
        "Не удалось синхронизировать прогресс сейчас (${e.message}). Повторим автоматически.",
      );
    } catch (_) {
      if (userId != null && progressStore != null) {
        unawaited(
          progressStore.upsertMirror(
            userId: userId,
            mediaItemId: mediaItemId,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            isCompleted: isCompleted,
            pendingSync: true,
          ),
        );
      }
      onTransientFailure("Временная ошибка синхронизации прогресса");
    }
  }
}

/// Догоняющая синхронизация локальных «pending» зеркал при появлении сети.
final class PendingProgressMirrorFlush {
  PendingProgressMirrorFlush(this._library);

  final LibraryRepository _library;

  Future<bool> flush({
    required AuthSession session,
    required String userId,
    required ProgressLocalStore progressStore,
  }) async {
    final pending = await progressStore.listPending(userId);
    var anySynced = false;
    for (final row in pending) {
      try {
        final synced = await _library.upsertMediaProgress(
          accessToken: session.accessToken,
          mediaItemId: row.mediaItemId,
          positionSeconds: row.positionSeconds,
          durationSeconds: row.durationSeconds,
          isCompleted: row.isCompleted,
        );
        await progressStore.upsertMirror(
          userId: userId,
          mediaItemId: row.mediaItemId,
          positionSeconds: synced.positionSeconds,
          durationSeconds: synced.durationSeconds,
          isCompleted: synced.isCompleted,
          pendingSync: false,
        );
        anySynced = true;
      } on ApiException {
        return anySynced;
      } catch (_) {
        return anySynced;
      }
    }
    return anySynced;
  }
}
