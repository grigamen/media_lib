import "dart:async";

import "package:flutter/material.dart";

import "../../../app/app_state.dart";
import "../../library/data/library_repository.dart";
import "../../library/presentation/library_screen.dart";

class MyWorksScreen extends StatefulWidget {
  const MyWorksScreen({required this.state, super.key});

  final AppState state;

  @override
  State<MyWorksScreen> createState() => _MyWorksScreenState();
}

class _MyWorksScreenState extends State<MyWorksScreen> {
  List<MediaListItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.state.fetchMyMediaItemsForPanel();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = "Не удалось загрузить список";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(title: const Text("Мои произведения")),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          return LibraryScreen(
            currentUserId: state.currentUserId,
            items: _items,
            usingDemoItems: false,
            isLoading: _loading,
            errorMessage: _error,
            onRefresh: _load,
            searchQuery: "",
            selectedTypes: const [],
            selectedGenres: const [],
            onSetLibraryFilters: (_, __, ___) async {},
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
            onOpenSearchTab: () {},
            onFetchMediaFiles: state.fetchMediaFilesForItem,
            onBindMainMediaFile: state.bindMainMediaFileToItem,
            onUploadAndBindMainMediaFile: state.uploadAndBindMainMediaFile,
            onFetchPlaybackStreamUrl: state.fetchPlaybackStreamUrl,
            hideLibraryControls: true,
            emptyLibraryMessage:
                "Вы ещё не добавляли произведений с этого аккаунта",
          );
        },
      ),
    );
  }
}
