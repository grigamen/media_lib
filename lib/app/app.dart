import "package:flutter/material.dart";

import "app_state.dart";
import "media_lib_shell.dart";
import "media_lib_theme.dart";

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
    // Keep MaterialApp outside AnimatedBuilder/ListenableBuilder so the app
    // shell is not rebuilt on every notifyListeners (e.g. profile PATCH while
    // a dialog route is closing — that pattern hit _dependents.isEmpty).
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "MediaLib",
      theme: buildMediaLibTheme(Brightness.light),
      darkTheme: buildMediaLibTheme(Brightness.dark),
      themeMode: ThemeMode.light,
      builder: (context, child) {
        return ListenableBuilder(
          listenable: _state,
          builder: (context, _) {
            final uploadProgress = _state.presignedUploadProgress;
            return Theme(
              data: buildMediaLibTheme(
                _state.isDarkMode ? Brightness.dark : Brightness.light,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child!,
                  if (uploadProgress != null)
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: ModalBarrier(
                            color: Colors.black45,
                            dismissible: false,
                          ),
                        ),
                        Center(
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 32,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                20,
                                24,
                                16,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    "Загрузка файла в хранилище…",
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      minHeight: 8,
                                      value: uploadProgress,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "${(uploadProgress * 100).clamp(0, 100).round()}%",
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () =>
                                        _state.dismissPresignedUploadOverlay(),
                                    child: const Text("Скрыть индикатор"),
                                  ),
                                  Text(
                                    "Если загрузка зависла, можно скрыть окно и "
                                    "повторить позже. Загрузка на сервер при этом "
                                    "может ещё продолжаться или оборваться.",
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
      home: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          if (!_state.isBootstrapComplete) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return _state.isAuthenticated
              ? MediaLibHomeShell(state: _state)
              : MediaLibAuthRoute(state: _state);
        },
      ),
    );
  }
}
