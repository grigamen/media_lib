import "package:flutter/material.dart";

import "../features/admin/presentation/admin_media_screen.dart";
import "../features/auth/presentation/auth_screen.dart";
import "../features/home/presentation/home_screen.dart";
import "../features/library/data/library_repository.dart";
import "../features/library/presentation/add_item_screen.dart";
import "../features/library/presentation/library_screen.dart";
import "../features/profile/presentation/profile_screen.dart";
import "../features/search/presentation/search_screen.dart";
import "app_state.dart";

class MediaLibApp extends StatefulWidget {
  const MediaLibApp({super.key});

  @override
  State<MediaLibApp> createState() => _MediaLibAppState();
}

class _MediaLibAppState extends State<MediaLibApp> {
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = AppState();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        return MaterialApp(
          title: "MediaLib",
          themeMode: _state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home:
              _state.isAuthenticated
                  ? _HomeShell(state: _state)
                  : _AuthRoute(state: _state),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    const seed = Color(0xFF6E52C8);
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
      useMaterial3: true,
    );
    final scheme = base.colorScheme;
    return base.copyWith(
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF12121B) : const Color(0xFFF1EFF4),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF272735) : const Color(0xFFE2DDEA),
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? const Color(0xFF151520) : const Color(0xFFF1EFF4),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.3 : 0.18),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor:
            isDark ? const Color(0xFF2B2B3B) : const Color(0xFFE0DCE8),
        selectedColor: scheme.primary,
        labelStyle: TextStyle(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: isDark ? const Color(0xFF1B1B27) : Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        ),
      ),
    );
  }
}

class _AuthRoute extends StatelessWidget {
  const _AuthRoute({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
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

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    Future<void> openItemFromHome(MediaListItem item) {
      final groupItems = _resolveGroupItems(item);
      return openMediaItemDetailsPage(
        context: context,
        currentUserId: state.currentUserId,
        groupItems: groupItems,
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
        onFetchMediaFiles: state.fetchMediaFilesForItem,
        onBindMainMediaFile: state.bindMainMediaFileToItem,
        onUploadAndBindMainMediaFile: state.uploadAndBindMainMediaFile,
        onFetchPlaybackStreamUrl: state.fetchPlaybackStreamUrl,
      );
    }

    final pages = <Widget>[
      HomeScreen(
        items: state.items,
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
        typeFilter: state.typeFilter,
        onApplyFilters:
            (searchQuery, typeFilter) => state.applyLibraryFilters(
              searchQuery: searchQuery,
              typeFilter: typeFilter,
            ),
        onAddItem:
            ({
              required String type,
              required String title,
              String? author,
              String? coverUrl,
              List<String>? genres,
              MediaUploadPayload? coverUploadPayload,
              MediaUploadPayload? uploadPayload,
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
        onFetchPlaybackStreamUrl: state.fetchPlaybackStreamUrl,
      ),
      AddItemScreen(
        onAddItem:
            ({
              required String type,
              required String title,
              String? author,
              String? coverUrl,
              List<String>? genres,
              MediaUploadPayload? coverUploadPayload,
              MediaUploadPayload? uploadPayload,
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
        onSearch:
            (query) =>
                state.applyLibraryFilters(searchQuery: query, typeFilter: null),
        onOpenLibrary: () => state.setSelectedTab(1),
      ),
      ProfileScreen(
        email: state.userEmail,
        isDarkMode: state.isDarkMode,
        onThemeToggle: state.toggleTheme,
        onDeleteAllWorks: state.deleteAllMediaItems,
        onOpenAddWork: () => state.setSelectedTab(2),
        onLogout: state.logout,
        onOpenAdminMedia:
            state.isAdminUser
                ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _AdminMediaShell(state: state),
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

    return Scaffold(
      body: pages[state.selectedTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedNavIndex,
        onDestinationSelected: (index) {
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
    );
  }

  List<MediaListItem> _resolveGroupItems(MediaListItem anchorItem) {
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
}

class _AdminMediaShell extends StatefulWidget {
  const _AdminMediaShell({required this.state});

  final AppState state;

  @override
  State<_AdminMediaShell> createState() => _AdminMediaShellState();
}

class _AdminMediaShellState extends State<_AdminMediaShell> {
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
          ),
    );
  }
}
