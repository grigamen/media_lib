import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../features/admin/presentation/admin_media_screen.dart";
import "../features/auth/presentation/auth_screen.dart";
import "../features/auth/presentation/email_two_fa_screen.dart";
import "../features/home/presentation/home_screen.dart";
import "../features/library/data/library_repository.dart";
import "../features/library/presentation/add_item/add_item_screen.dart";
import "../features/library/presentation/library/library_screen.dart";
import "../features/profile/presentation/my_works/my_works_screen.dart";
import "../features/profile/presentation/profile/profile_screen.dart";
import "../features/search/presentation/search_screen.dart";
import "app_state.dart";

// Корневой виджет приложения: табы, маршруты экранов и привязка к [AppState].

/// Элементы одной «работы» (один заголовок/автор, разные форматы/варианты).
List<MediaListItem> mediaItemsInWorkGroup(
  AppState state,
  MediaListItem anchorItem,
) {
  final titleKey = anchorItem.title.trim().toLowerCase();
  final authorKey = (anchorItem.author ?? "").trim().toLowerCase();
  final grouped = state.items
      .where(
        (item) =>
            item.title.trim().toLowerCase() == titleKey &&
            (item.author ?? "").trim().toLowerCase() == authorKey,
      )
      .toList(growable: false);
  if (grouped.isNotEmpty) {
    return grouped;
  }
  return [anchorItem];
}

Future<void> openWorkGroupItemDetails(
  BuildContext context,
  AppState state,
  List<MediaListItem> groupItems,
) {
  return openMediaItemDetailsForAppState(
    context: context,
    state: state,
    groupItems: groupItems,
  );
}

/// Маршрут до входа в приложение: [AuthScreen] или экран ввода кода 2FA.
class MediaLibAuthRoute extends StatelessWidget {
  const MediaLibAuthRoute({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.hasPendingEmailTwoFa) {
      return EmailTwoFaScreen(
        email: state.pendingTwoFaEmail ?? "",
        displayName: state.pendingTwoFaDisplayName ?? "",
        hintMessage: state.pendingTwoFaMessage,
        isLoading: state.isAuthLoading,
        errorMessage: state.authError,
        onVerify: state.submitEmailTwoFaCode,
        onResend: state.resendEmailTwoFaCode,
        onBackToLogin: state.cancelEmailTwoFaLogin,
      );
    }
    return AuthScreen(
      isLoading: state.isAuthLoading,
      errorMessage: state.authError,
      onLogin:
          (email, password) => state.login(email: email, password: password),
      onRegister:
          (email, password, displayName) => state.register(
            email: email,
            password: password,
            displayName: displayName,
          ),
    );
  }
}

/// Основной [Scaffold] с нижними вкладками: дом, библиотека, добавление, поиск, профиль.
class MediaLibHomeShell extends StatefulWidget {
  const MediaLibHomeShell({required this.state, super.key});

  final AppState state;

  @override
  State<MediaLibHomeShell> createState() => _MediaLibHomeShellState();
}

class _MediaLibHomeShellState extends State<MediaLibHomeShell> {
  DateTime? _lastExitBackPress;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    Future<void> openItemFromHome(MediaListItem item) {
      return openWorkGroupItemDetails(
        context,
        state,
        mediaItemsInWorkGroup(state, item),
      );
    }

    final pages = <Widget>[
      HomeScreen(
        recentlyViewedItems: state.recentlyViewedItems,
        onOpenItem: openItemFromHome,
      ),
      LibraryScreen(
        currentUserId: state.currentUserId,
        items: state.items,
        usingDemoItems: state.usingDemoItems,
        isLoading: state.isLibraryLoading,
        errorMessage: state.libraryError,
        onRefresh: state.fetchLibrary,
        searchQuery: state.searchQuery,
        selectedTypes: state.selectedTypes,
        selectedGenres: state.selectedGenres,
        onSetLibraryFilters:
            (query, types, genres) => state.applyLibraryFilters(
              searchQuery: query,
              selectedTypes: types,
              selectedGenres: genres,
            ),
        availableGenres: state.availableGenres,
        onLoadLinks: state.fetchLinksForItem,
        onLoadItemById: state.fetchMediaItemById,
        onUpdateItem:
            ({
              required mediaItemId,
              required type,
              required title,
              author,
              coverUrl,
              genres,
              coverUploadPayload,
              uploadPayload,
              description,
            }) => state.updateMediaItem(
              mediaItemId: mediaItemId,
              type: type,
              title: title,
              author: author,
              coverUrl: coverUrl,
              genres: genres,
              coverUploadPayload: coverUploadPayload,
              uploadPayload: uploadPayload,
              description: description,
            ),
        onAddFormatToWork:
            ({
              required sourceMediaItemId,
              required type,
              required title,
              author,
              coverUrl,
              genres,
              coverUploadPayload,
              description,
              uploadPayload,
            }) => state.addFormatToWork(
              sourceMediaItemId: sourceMediaItemId,
              type: type,
              title: title,
              author: author,
              coverUrl: coverUrl,
              genres: genres,
              coverUploadPayload: coverUploadPayload,
              description: description,
              uploadPayload: uploadPayload,
            ),
        onBeginPlaybackSession: state.beginPlaybackSession,
        onPlaybackProgressChanged: state.updatePlaybackProgress,
        onPausePlaybackSession: state.pausePlaybackSession,
        onCompletePlaybackSession: state.completePlaybackSession,
        onFlushPlaybackSession: state.flushPlaybackProgress,
        onEndPlaybackSession: state.endPlaybackSession,
        playbackSpeed: state.playbackSpeed,
        onSetPlaybackSpeed: state.setPlaybackSpeed,
        pendingPlaybackSync: state.pendingPlaybackSync,
        playbackError: state.playbackError,
        onLoadBookContent: state.loadBookContent,
        onMarkItemViewed: state.markItemViewed,
        onOpenSearchTab: () => state.setSelectedTab(3),
        onFetchMediaFiles: state.fetchMediaFilesForItem,
        onBindMainMediaFile: state.bindMainMediaFileToItem,
        onUploadAndBindMainMediaFile: state.uploadAndBindMainMediaFile,
        onFetchMediaProgress: state.fetchMediaProgressForItem,
        onSetMediaItemUserRating: ({
          required String mediaItemId,
          required int stars,
        }) => state.setMediaItemUserRating(
          mediaItemId: mediaItemId,
          stars: stars,
        ),
        onClearMediaItemUserRating: state.clearMediaItemUserRating,
        onFetchWorkUserRating: state.fetchWorkUserRatingStars,
        onSetWorkUserRating: ({
          required List<String> mediaItemIds,
          required int stars,
        }) => state.setWorkUserRatingStars(
          mediaItemIds: mediaItemIds,
          stars: stars,
        ),
        onClearWorkUserRating: state.clearWorkUserRatingStars,
        onFetchPlaybackStreamUrl: state.fetchPlaybackStreamUrl,
      ),
      AddItemScreen(
        onAddItem:
            ({
              required type,
              required title,
              author,
              coverUrl,
              genres,
              coverUploadPayload,
              uploadPayload,
            }) => state.createMediaItem(
              type: type,
              title: title,
              author: author,
              coverUrl: coverUrl,
              genres: genres,
              coverUploadPayload: coverUploadPayload,
              uploadPayload: uploadPayload,
            ),
        availableGenres: state.availableGenres,
      ),
      SearchScreen(
        initialQuery: state.searchQuery,
        selectedTypes: state.selectedTypes,
        selectedGenres: state.selectedGenres,
        availableGenres: state.availableGenres,
        onApply:
            (query, types, genres) => state.applyLibraryFilters(
              searchQuery: query,
              selectedTypes: types,
              selectedGenres: genres,
            ),
        onOpenLibrary: () => state.setSelectedTab(1),
      ),
      ProfileScreen(
        email: state.userEmail,
        displayName: state.userDisplayName,
        twofaEnabled: state.userTwofaEnabled,
        onStartTwoFaEnable: state.startTwoFaEnableFromProfile,
        onConfirmTwoFaEnable: state.confirmTwoFaEnableFromProfile,
        onDisableTwoFa: state.disableTwoFaFromProfile,
        isDarkMode: state.isDarkMode,
        hasOwnedWorks: state.hasOwnedWorks,
        onThemeToggle: state.toggleTheme,
        onDeleteAllWorks: state.deleteAllMediaItems,
        onOpenAddWork: () => state.setSelectedTab(2),
        onLogout: state.logout,
        onUpdateProfile:
            ({required displayName, newEmail, currentPasswordForEmail}) =>
                state.updateUserProfile(
                  displayName: displayName,
                  newEmail: newEmail,
                  currentPasswordForEmail: currentPasswordForEmail,
                ),
        onChangePassword:
            ({required currentPassword, required newPassword}) =>
                state.changeUserPassword(
                  currentPassword: currentPassword,
                  newPassword: newPassword,
                ),
        onOpenMyWorks: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MyWorksScreen(state: state),
            ),
          );
        },
        onOpenAdminMedia:
            state.isAdminUser
                ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MediaLibAdminMediaShell(state: state),
                    ),
                  );
                }
                : null,
      ),
    ];

    final selectedNavIndex = switch (state.selectedTab) {
      0 => 0,
      4 => 2,
      _ => 1,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (!mounted) {
          return;
        }
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
          return;
        }
        final tab = state.selectedTab;
        if (tab == 2 || tab == 3) {
          state.setSelectedTab(1);
          return;
        }
        if (tab == 4) {
          state.setSelectedTab(1);
          return;
        }
        final now = DateTime.now();
        if (_lastExitBackPress != null &&
            now.difference(_lastExitBackPress!) < const Duration(seconds: 2)) {
          _lastExitBackPress = null;
          SystemNavigator.pop();
          return;
        }
        _lastExitBackPress = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Нажмите «Назад» ещё раз, чтобы выйти"),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        // IndexedStack держит все вкладки смонтированными: иначе при любом
        // notifyListeners (прогресс, библиотека…) пересоздаётся только текущая
        // страница и ломаются диалоги профиля (2FA): _dependents.isEmpty.
        body: IndexedStack(
          index: state.selectedTab.clamp(0, pages.length - 1),
          sizing: StackFit.expand,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedNavIndex,
          onDestinationSelected: (index) {
            _lastExitBackPress = null;
            switch (index) {
              case 0:
                state.setSelectedTab(0);
              case 1:
                state.setSelectedTab(1);
              case 2:
                state.setSelectedTab(4);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: "Главная",
            ),
            NavigationDestination(
              icon: Icon(Icons.video_library_outlined),
              selectedIcon: Icon(Icons.video_library),
              label: "Библиотека",
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: "Профиль",
            ),
          ],
        ),
      ),
    );
  }
}

/// Корень админ-ветки: каталог на модерации и удаление (отдельный навигатор).
class MediaLibAdminMediaShell extends StatefulWidget {
  const MediaLibAdminMediaShell({required this.state, super.key});

  final AppState state;

  @override
  State<MediaLibAdminMediaShell> createState() =>
      _MediaLibAdminMediaShellState();
}

class _MediaLibAdminMediaShellState extends State<MediaLibAdminMediaShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.state.fetchAdminCatalog();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder:
          (context, _) => AdminMediaScreen(
            pendingItems: widget.state.adminPendingItems,
            allItems: widget.state.adminAllItems,
            isLoading: widget.state.isAdminCatalogLoading,
            isLoadingMorePending: widget.state.isAdminPendingLoadingMore,
            hasMorePending: widget.state.adminPendingHasMore,
            isLoadingMoreAll: widget.state.isAdminAllLoadingMore,
            hasMoreAll: widget.state.adminAllHasMore,
            errorMessage: widget.state.adminCatalogError,
            onRefresh: widget.state.fetchAdminCatalog,
            onLoadMorePending: widget.state.loadMoreAdminPendingCatalog,
            onLoadMoreAll: widget.state.loadMoreAdminAllCatalog,
            onDeleteItem: widget.state.deleteMediaItemAsAdmin,
            onModerateItem:
                (mediaItemId, approve) => widget.state.moderateMediaItemAsAdmin(
                  mediaItemId: mediaItemId,
                  approve: approve,
                ),
            onOpenItem:
                (item) => openWorkGroupItemDetails(
                  context,
                  widget.state,
                  mediaItemsInWorkGroup(widget.state, item),
                ),
          ),
    );
  }
}
