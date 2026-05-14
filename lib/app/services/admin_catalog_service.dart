import "../../core/network/api_client.dart";
import "../../features/auth/data/auth_repository.dart";
import "../../features/library/data/library_repository.dart";

import "cover_url_refresh_service.dart";
import "media_catalog_utils.dart";

class AdminCatalogState {
  List<MediaListItem> pendingItems = const [];
  List<MediaListItem> allItems = const [];
  int pendingTotal = 0;
  int allTotal = 0;
  bool isPendingLoadingMore = false;
  bool isAllLoadingMore = false;
  bool isCatalogLoading = false;
  String? error;
}

/// Загрузка и пагинация админских списков каталога.
final class AdminCatalogService {
  AdminCatalogService({
    required LibraryRepository library,
    required CoverUrlRefreshService coverRefresh,
    void Function()? onChanged,
  }) : _library = library,
       _coverRefresh = coverRefresh,
       _onChanged = onChanged;

  static const int pageSize = 40;

  final LibraryRepository _library;
  final CoverUrlRefreshService _coverRefresh;
  final void Function()? _onChanged;

  final AdminCatalogState state = AdminCatalogState();

  bool get pendingHasMore => state.pendingItems.length < state.pendingTotal;

  bool get allHasMore => state.allItems.length < state.allTotal;

  void _emit() => _onChanged?.call();

  void reset() {
    state.pendingItems = const [];
    state.allItems = const [];
    state.pendingTotal = 0;
    state.allTotal = 0;
    state.isPendingLoadingMore = false;
    state.isAllLoadingMore = false;
    state.isCatalogLoading = false;
    state.error = null;
  }

  void removeItemFromEverywhere(String mediaItemId) {
    state.pendingItems = state.pendingItems
        .where((e) => e.id != mediaItemId)
        .toList(growable: false);
    state.allItems = state.allItems
        .where((e) => e.id != mediaItemId)
        .toList(growable: false);
  }

  Future<void> fetchCatalog({
    required AuthSession session,
    required bool isAdminUser,
    bool showLoadingIndicator = true,
  }) async {
    if (!isAdminUser) {
      return;
    }
    if (showLoadingIndicator) {
      state.isCatalogLoading = true;
    }
    state.isPendingLoadingMore = false;
    state.isAllLoadingMore = false;
    state.error = null;
    _emit();
    try {
      final pendingRes = await _library.fetchMediaItemsWithMeta(
        accessToken: session.accessToken,
        moderationStatus: "pending",
        limit: pageSize,
        offset: 0,
      );
      final allRes = await _library.fetchMediaItemsWithMeta(
        accessToken: session.accessToken,
        limit: pageSize,
        offset: 0,
        excludePending: true,
      );
      state.pendingTotal = pendingRes.total;
      state.allTotal = allRes.total;
      state.pendingItems = await _coverRefresh.withFreshCoverUrls(
        session: session,
        items: pendingRes.items,
      );
      state.allItems = await _coverRefresh.withFreshCoverUrls(
        session: session,
        items: allRes.items,
      );
    } on ApiException catch (e) {
      state.error = e.message;
    } catch (_) {
      state.error = "Не удалось загрузить каталог";
    } finally {
      if (showLoadingIndicator) {
        state.isCatalogLoading = false;
      }
      _emit();
    }
  }

  Future<void> loadMorePending({
    required AuthSession session,
    required bool isAdminUser,
  }) async {
    if (!isAdminUser || !pendingHasMore || state.isPendingLoadingMore) {
      return;
    }
    state.isPendingLoadingMore = true;
    _emit();
    try {
      final res = await _library.fetchMediaItemsWithMeta(
        accessToken: session.accessToken,
        moderationStatus: "pending",
        limit: pageSize,
        offset: state.pendingItems.length,
      );
      state.pendingTotal = res.total;
      final merged = dedupeMediaItemsById([
        ...state.pendingItems,
        ...res.items,
      ]);
      state.pendingItems = await _coverRefresh.withFreshCoverUrls(
        session: session,
        items: merged,
      );
    } on ApiException catch (e) {
      state.error = e.message;
    } catch (_) {
      state.error = "Не удалось загрузить каталог";
    } finally {
      state.isPendingLoadingMore = false;
      _emit();
    }
  }

  Future<void> loadMoreAll({
    required AuthSession session,
    required bool isAdminUser,
  }) async {
    if (!isAdminUser || !allHasMore || state.isAllLoadingMore) {
      return;
    }
    state.isAllLoadingMore = true;
    _emit();
    try {
      final res = await _library.fetchMediaItemsWithMeta(
        accessToken: session.accessToken,
        limit: pageSize,
        offset: state.allItems.length,
        excludePending: true,
      );
      state.allTotal = res.total;
      final merged = dedupeMediaItemsById([...state.allItems, ...res.items]);
      state.allItems = await _coverRefresh.withFreshCoverUrls(
        session: session,
        items: merged,
      );
    } on ApiException catch (e) {
      state.error = e.message;
    } catch (_) {
      state.error = "Не удалось загрузить каталог";
    } finally {
      state.isAllLoadingMore = false;
      _emit();
    }
  }
}
