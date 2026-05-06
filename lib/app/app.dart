import "package:flutter/material.dart";

import "../features/auth/presentation/auth_screen.dart";
import "../features/library/presentation/library_screen.dart";
import "../features/profile/presentation/profile_screen.dart";
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
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.dark,
              seedColor: Colors.indigo,
            ),
            useMaterial3: true,
          ),
          home: _state.isAuthenticated ? _HomeShell(state: _state) : _AuthRoute(state: _state),
        );
      },
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
      onLogin: (email, password) => state.login(email: email, password: password),
      onRegister: (email, password, displayName) => state.register(
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
    final pages = <Widget>[
      LibraryScreen(
        items: state.items,
        usingDemoItems: state.usingDemoItems,
        isLoading: state.isLibraryLoading,
        errorMessage: state.libraryError,
        onRefresh: state.fetchLibrary,
        searchQuery: state.searchQuery,
        typeFilter: state.typeFilter,
        onApplyFilters: (searchQuery, typeFilter) => state.applyLibraryFilters(
          searchQuery: searchQuery,
          typeFilter: typeFilter,
        ),
        onAddItem: (type, title, author) => state.createMediaItem(
          type: type,
          title: title,
          author: author,
        ),
        onLoadLinks: state.fetchLinksForItem,
        onLoadItemById: state.fetchMediaItemById,
      ),
      ProfileScreen(
        email: state.userEmail,
        isDarkMode: state.isDarkMode,
        onThemeToggle: state.toggleTheme,
        onLogout: state.logout,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(state.selectedTab == 0 ? "Библиотека" : "Профиль"),
        actions: [
          if (state.selectedTab == 0)
            IconButton(
              onPressed: state.isLibraryLoading ? null : state.fetchLibrary,
              icon: const Icon(Icons.refresh),
              tooltip: "Обновить",
            ),
        ],
      ),
      body: pages[state.selectedTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.selectedTab,
        onDestinationSelected: state.setSelectedTab,
        destinations: const [
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
}
