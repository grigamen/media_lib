import "../../core/network/api_client.dart";
import "../../features/auth/data/auth_repository.dart";
import "../../features/library/data/library_repository.dart";

class AdminReportsState {
  List<CommentReportItem> pendingReports = const [];
  int pendingTotal = 0;
  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
}

/// Загрузка и пагинация жалоб на комментарии для админ-панели.
final class AdminReportsService {
  AdminReportsService({
    required LibraryRepository library,
    void Function()? onChanged,
  }) : _library = library,
       _onChanged = onChanged;

  static const int pageSize = 40;

  final LibraryRepository _library;
  final void Function()? _onChanged;

  final AdminReportsState state = AdminReportsState();

  bool get pendingHasMore => state.pendingReports.length < state.pendingTotal;

  void _emit() => _onChanged?.call();

  void reset() {
    state.pendingReports = const [];
    state.pendingTotal = 0;
    state.isLoading = false;
    state.isLoadingMore = false;
    state.error = null;
  }

  void removeReport(String reportId) {
    state.pendingReports = state.pendingReports
        .where((report) => report.id != reportId)
        .toList(growable: false);
    if (state.pendingTotal > 0) {
      state.pendingTotal -= 1;
    }
  }

  Future<void> fetchPendingReports({
    required AuthSession session,
    required bool isAdminUser,
    bool showLoadingIndicator = true,
  }) async {
    if (!isAdminUser) {
      return;
    }
    if (showLoadingIndicator) {
      state.isLoading = true;
    }
    state.isLoadingMore = false;
    state.error = null;
    _emit();
    try {
      final result = await _library.fetchAdminCommentReports(
        accessToken: session.accessToken,
        limit: pageSize,
        offset: 0,
      );
      state.pendingTotal = result.total;
      state.pendingReports = result.items;
    } on ApiException catch (e) {
      state.error = e.message;
    } catch (_) {
      state.error = "Не удалось загрузить жалобы";
    } finally {
      if (showLoadingIndicator) {
        state.isLoading = false;
      }
      _emit();
    }
  }

  Future<void> loadMorePendingReports({
    required AuthSession session,
    required bool isAdminUser,
  }) async {
    if (!isAdminUser || !pendingHasMore || state.isLoadingMore) {
      return;
    }
    state.isLoadingMore = true;
    _emit();
    try {
      final result = await _library.fetchAdminCommentReports(
        accessToken: session.accessToken,
        limit: pageSize,
        offset: state.pendingReports.length,
      );
      state.pendingTotal = result.total;
      state.pendingReports = [
        ...state.pendingReports,
        ...result.items,
      ];
    } on ApiException catch (e) {
      state.error = e.message;
    } catch (_) {
      state.error = "Не удалось загрузить жалобы";
    } finally {
      state.isLoadingMore = false;
      _emit();
    }
  }
}
