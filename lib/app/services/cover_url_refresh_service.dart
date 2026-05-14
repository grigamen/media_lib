import "../../core/network/api_client.dart";
import "../../features/auth/data/auth_repository.dart";
import "../../features/library/data/library_repository.dart";

/// Подмена signed cover URL по [MediaListItem.coverFileId].
final class CoverUrlRefreshService {
  CoverUrlRefreshService(this._library);

  final LibraryRepository _library;

  Future<List<MediaListItem>> withFreshCoverUrls({
    required AuthSession session,
    required List<MediaListItem> items,
  }) async {
    final refreshed = <MediaListItem>[];
    for (final item in items) {
      final resolved = await withFreshCoverUrl(session: session, item: item);
      refreshed.add(resolved);
    }
    return refreshed;
  }

  Future<MediaListItem> withFreshCoverUrl({
    required AuthSession session,
    required MediaListItem item,
  }) async {
    final coverFileId = item.coverFileId;
    if (coverFileId == null || coverFileId.isEmpty) {
      return item;
    }
    try {
      final stream = await _library.fetchMediaStreamUrl(
        accessToken: session.accessToken,
        fileId: coverFileId,
      );
      if (stream.streamUrl.trim().isEmpty) {
        return item;
      }
      return item.copyWith(coverUrl: stream.streamUrl);
    } on ApiException {
      return item;
    } catch (_) {
      return item;
    }
  }
}
