import "dart:async";

import "package:file_picker/file_picker.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:video_player/video_player.dart";

import "../../../app/app_state.dart";
import "../../../core/audio/audiobook_audio_handler.dart";
import "../../../core/files/media_upload_file_pick.dart";
import "../../../core/network/api_client.dart";
import "../data/library_repository.dart";
import "book_reader_screen.dart";

part 'library_screen_helpers.dart';
part 'library_screen_list.dart';
part 'library_screen_details_page.dart';
part 'library_screen_details_state.dart';
part 'library_screen_owner_file_card_widget.dart';
part 'library_screen_owner_file_card_state.dart';
part 'library_screen_book_panel.dart';
part 'library_screen_playable_panel_widget.dart';
part 'library_screen_playable_panel_state.dart';
part 'library_screen_main_state.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.currentUserId,
    required this.items,
    required this.usingDemoItems,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.searchQuery,
    required this.selectedTypes,
    required this.selectedGenres,
    required this.onSetLibraryFilters,
    required this.availableGenres,
    required this.onLoadLinks,
    required this.onLoadItemById,
    required this.onUpdateItem,
    required this.onAddFormatToWork,
    required this.onBeginPlaybackSession,
    required this.onPlaybackProgressChanged,
    required this.onPausePlaybackSession,
    required this.onCompletePlaybackSession,
    required this.onFlushPlaybackSession,
    required this.onEndPlaybackSession,
    required this.playbackSpeed,
    required this.onSetPlaybackSpeed,
    required this.pendingPlaybackSync,
    required this.onFetchPlaybackStreamUrl,
    required this.playbackError,
    required this.onLoadBookContent,
    required this.onMarkItemViewed,
    required this.onOpenSearchTab,
    required this.onFetchMediaFiles,
    required this.onBindMainMediaFile,
    required this.onUploadAndBindMainMediaFile,
    this.hideLibraryControls = false,
    this.emptyLibraryMessage,
    super.key,
  });

  final String? currentUserId;
  final List<MediaListItem> items;
  final bool usingDemoItems;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final String searchQuery;
  final List<String> selectedTypes;
  final List<String> selectedGenres;
  final Future<void> Function(
    String searchQuery,
    List<String> selectedTypes,
    List<String> selectedGenres,
  )
  onSetLibraryFilters;
  final List<String> availableGenres;
  final Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks;
  final Future<MediaListItem?> Function(String mediaItemId) onLoadItemById;
  final Future<MediaListItem> Function({
    required String mediaItemId,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    MediaUploadPayload? uploadPayload,
    String? description,
  })
  onUpdateItem;
  final Future<MediaListItem> Function({
    required String sourceMediaItemId,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    String? description,
    MediaUploadPayload? uploadPayload,
  })
  onAddFormatToWork;
  final Future<PlaybackSessionOutcome> Function(MediaListItem item)
  onBeginPlaybackSession;
  final void Function({
    required int positionSeconds,
    required int? durationSeconds,
    required bool isPlaying,
    bool isCompleted,
  })
  onPlaybackProgressChanged;
  final Future<void> Function() onPausePlaybackSession;
  final Future<void> Function() onCompletePlaybackSession;
  final Future<void> Function() onFlushPlaybackSession;
  final void Function() onEndPlaybackSession;
  final double playbackSpeed;
  final void Function(double) onSetPlaybackSpeed;
  final bool pendingPlaybackSync;
  final Future<String?> Function(String fileId) onFetchPlaybackStreamUrl;
  final String? playbackError;
  final Future<String> Function(MediaListItem item) onLoadBookContent;
  final void Function(String mediaItemId) onMarkItemViewed;
  final VoidCallback onOpenSearchTab;
  final Future<List<MediaFileSummary>> Function(String mediaItemId)
  onFetchMediaFiles;
  final Future<void> Function({
    required String mediaItemId,
    required String fileId,
  })
  onBindMainMediaFile;
  final Future<void> Function({
    required String mediaItemId,
    required MediaUploadPayload uploadPayload,
  })
  onUploadAndBindMainMediaFile;

  /// Если true — скрыты поиск и чипы фильтров (экран «только мои произведения»).
  final bool hideLibraryControls;

  /// Текст при пустом списке вместо стандартного «Библиотека пока пустая».
  final String? emptyLibraryMessage;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}
