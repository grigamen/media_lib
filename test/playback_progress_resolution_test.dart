import "package:flutter_test/flutter_test.dart";
import "package:media_lib/core/local/progress_local_store.dart";
import "package:media_lib/core/sync/playback_progress_resolution.dart";

void main() {
  group("PlaybackProgressResolution", () {
    test("prefer server when no local row", () {
      final r = PlaybackProgressResolution.resolve(
        serverPositionSeconds: 12,
        serverDurationSeconds: 100,
        serverIsCompleted: false,
        serverUpdatedAtUtcMs: 1000,
        local: null,
      );
      expect(r.positionSeconds, 12);
      expect(r.needsPushToServer, false);
    });

    test("prefer local when local wall time is strictly newer", () {
      final local = ProgressMirrorRow(
        mediaItemId: "m1",
        positionSeconds: 90,
        durationSeconds: 100,
        isCompleted: false,
        pendingSync: false,
        updatedAtLocalMs: 2000,
      );
      final r = PlaybackProgressResolution.resolve(
        serverPositionSeconds: 10,
        serverDurationSeconds: 100,
        serverIsCompleted: false,
        serverUpdatedAtUtcMs: 1000,
        local: local,
      );
      expect(r.positionSeconds, 90);
      expect(r.needsPushToServer, true);
    });

    test("prefer local on timestamp tie when pending_sync", () {
      final local = ProgressMirrorRow(
        mediaItemId: "m1",
        positionSeconds: 88,
        durationSeconds: 100,
        isCompleted: false,
        pendingSync: true,
        updatedAtLocalMs: 1000,
      );
      final r = PlaybackProgressResolution.resolve(
        serverPositionSeconds: 10,
        serverDurationSeconds: 100,
        serverIsCompleted: false,
        serverUpdatedAtUtcMs: 1000,
        local: local,
      );
      expect(r.positionSeconds, 88);
      expect(r.needsPushToServer, true);
    });

    test("prefer server on timestamp tie when not pending_sync", () {
      final local = ProgressMirrorRow(
        mediaItemId: "m1",
        positionSeconds: 88,
        durationSeconds: 100,
        isCompleted: false,
        pendingSync: false,
        updatedAtLocalMs: 1000,
      );
      final r = PlaybackProgressResolution.resolve(
        serverPositionSeconds: 42,
        serverDurationSeconds: 100,
        serverIsCompleted: false,
        serverUpdatedAtUtcMs: 1000,
        local: local,
      );
      expect(r.positionSeconds, 42);
      expect(r.needsPushToServer, false);
    });
  });
}
