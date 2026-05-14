import "../features/library/data/library_repository.dart";

enum PlaybackLoadState { idle, loading, ready, error }

class PlaybackStreamOption {
  const PlaybackStreamOption({required this.fileId, required this.label});

  final String fileId;
  final String label;
}

class PlaybackSessionConfig {
  const PlaybackSessionConfig({
    required this.mediaItemId,
    required this.mediaType,
    required this.streamUrl,
    required this.initialPositionSeconds,
    required this.initialDurationSeconds,
    required this.initialSpeed,
    required this.isDemoStream,
    this.streamOptions = const [],
    this.activeStreamFileId,
  });

  final String mediaItemId;
  final String mediaType;
  final String streamUrl;
  final int initialPositionSeconds;
  final int? initialDurationSeconds;
  final double initialSpeed;
  final bool isDemoStream;
  final List<PlaybackStreamOption> streamOptions;
  final String? activeStreamFileId;
}

/// Результат запуска сессии воспроизведения ([config] или [errorMessage], не оба сразу).
class PlaybackSessionOutcome {
  PlaybackSessionOutcome.success(this.config) : errorMessage = null;

  PlaybackSessionOutcome.failure(this.errorMessage) : config = null;

  final PlaybackSessionConfig? config;
  final String? errorMessage;
}

String _shortMediaFileIdForLabel(String id) {
  if (id.length <= 10) {
    return id;
  }
  return "${id.substring(0, 8)}…";
}

List<PlaybackStreamOption> playbackStreamOptionsFromFiles(
  List<MediaFileSummary> readySortedAsc,
) {
  return readySortedAsc
      .map(
        (f) => PlaybackStreamOption(
          fileId: f.id,
          label: "${f.contentType} · ${_shortMediaFileIdForLabel(f.id)}",
        ),
      )
      .toList(growable: false);
}

/// Файлы, которые можно предлагать как варианты потока (без обложек и чужих типов).
List<MediaFileSummary> playbackStreamCandidates(
  List<MediaFileSummary> readySortedAsc,
  String mediaType,
) {
  return readySortedAsc.where((f) {
    final ct = f.contentType.trim().toLowerCase();
    if (ct.startsWith("image/")) {
      return false;
    }
    if (mediaType == "video") {
      return ct.startsWith("video/") || ct == "application/octet-stream";
    }
    if (mediaType == "audiobook") {
      return ct.startsWith("audio/") || ct == "application/octet-stream";
    }
    return false;
  }).toList(growable: false);
}

String? pickPlaybackFileIdFromReady(
  List<MediaFileSummary> readySortedAsc,
  String? preferredId,
) {
  if (readySortedAsc.isEmpty) {
    return null;
  }
  if (preferredId != null && preferredId.isNotEmpty) {
    for (final f in readySortedAsc) {
      if (f.id == preferredId) {
        return preferredId;
      }
    }
  }
  return readySortedAsc.first.id;
}
