import "dart:async";

import "package:file_picker/file_picker.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:video_player/video_player.dart";

import "../../../../app/app_state.dart";
import "../../../../core/audio/audiobook_audio_handler.dart";
import "../../../../core/files/media_upload_file_pick.dart";
import "../../../../core/network/api_client.dart";
import "../../data/library_repository.dart";
import "../../data/library_filters.dart";
import "../../data/library_sort.dart";
import "../../../shelves/presentation/add_to_shelf_dialog.dart";
import "../book_reader/book_reader_screen.dart";
import "../media_cover.dart";

// Здесь собран весь экран «Библиотека»: сетка обложек, открытие карточки, чтение, прослушивание, загрузка файлов.
// Сам код разбит на отдельные файлы ниже (part), чтобы не держать тысячи строк в одном месте.

part 'library_screen_helpers.dart';
part 'library_screen_list.dart';
part 'library_screen_details_page.dart';
part 'library_screen_details_fields.dart';
part 'library_screen_details_lifecycle.dart';
part 'library_screen_details_dialog_edit.dart';
part 'library_screen_details_dialog_add_format.dart';
part 'library_screen_details_state.dart';
part 'library_screen_owner_file_card_widget.dart';
part 'library_screen_owner_file_card_state.dart';
part 'library_screen_book_panel.dart';
part 'library_screen_playable_panel_widget.dart';
part 'library_screen_playable_panel_fields.dart';
part 'library_screen_playable_panel_player_core.dart';
part 'library_screen_playable_panel_player.dart';
part 'library_screen_playable_panel_state.dart';
part 'library_screen_main_state.dart';

// Виджет списка каталога. Данные и действия (загрузить, сохранить, включить плеер) приходят извне —
// обычно из состояния всего приложения, когда вы нажимаете вкладку «Библиотека».
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.currentUserId,
    required this.isAdminUser,
    required this.items,
    required this.usingDemoItems,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.searchQuery,
    required this.selectedTypes,
    required this.selectedGenres,
    required this.libraryRatingCriteria,
    required this.libraryViewsCriteria,
    required this.librarySortField,
    required this.librarySortDescending,
    required this.onSetLibrarySortField,
    required this.onToggleLibrarySortDirection,
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
    required this.onRecordMediaItemView,
    required this.onMarkItemViewed,
    required this.onOpenSearchTab,
    required this.onFetchMediaFiles,
    required this.onBindMainMediaFile,
    required this.onUploadAndBindMainMediaFile,
    required this.onFetchMediaProgress,
    required this.onSetMediaItemUserRating,
    required this.onClearMediaItemUserRating,
    required this.onFetchWorkUserRating,
    required this.onSetWorkUserRating,
    required this.onClearWorkUserRating,
    required this.onFetchMediaComments,
    required this.onCreateMediaComment,
    required this.onUpdateMediaComment,
    required this.onDeleteMediaComment,
    required this.onReportMediaComment,
    required this.onFetchItemsByAuthor,
    required this.onAddToShelf,
    this.onHasBookOfflineCopy,
    this.onDownloadBookForOffline,
    this.onSaveAuthorBookLocalFile,
    this.hideLibraryControls = false,
    this.emptyLibraryMessage,
    super.key,
  });

  final String? currentUserId; // кто сейчас вошёл — нужно, чтобы показать «это ваше» и разрешить правки
  final bool isAdminUser;
  final List<MediaListItem> items; // всё, что пришло с сервера одним списком (потом сгруппируем по произведениям)
  final bool usingDemoItems; // если на сервере пусто, показываем тестовые карточки, чтобы экран не был пустым
  final bool isLoading; // идёт загрузка списка (первый раз или обновление)
  final String? errorMessage; // если что-то пошло не так — сюда текст ошибки для пользователя
  final Future<void> Function() onRefresh; // потянуть список вниз — попросить сервер отдать свежие данные
  final String searchQuery; // что пользователь искал в прошлый раз (строка поиска)
  final List<String> selectedTypes; // какие виды контента включены в фильтре: книга / аудио / видео
  final List<String> selectedGenres; // какие жанры выбраны в фильтре
  final LibraryRatingCriteria libraryRatingCriteria;
  final LibraryViewsCriteria libraryViewsCriteria;
  final Future<void> Function(
    String searchQuery,
    List<String> selectedTypes,
    List<String> selectedGenres,
    LibraryRatingCriteria ratingCriteria,
    LibraryViewsCriteria viewsCriteria,
  )
  onSetLibraryFilters; // пользователь поменял поиск или фильтры — сохранить и перезагрузить список
  final LibrarySortField librarySortField;
  final bool librarySortDescending;
  final void Function(LibrarySortField field) onSetLibrarySortField;
  final VoidCallback onToggleLibrarySortDirection;
  final List<String> availableGenres; // список жанров, который можно выбрать (из приложения)
  final Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks; // узнать, с чем на сервере связана эта запись
  final Future<MediaListItem?> Function(String mediaItemId) onLoadItemById; // забрать одну свежую карточку по её номеру на сервере
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
  onUpdateItem; // сохранить изменения названия, автора, обложки и т.д. для одного варианта (например только книга)
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
  onAddFormatToWork; // к тому же произведению добавить ещё один формат: например уже есть книга — добавить аудио
  final Future<PlaybackSessionOutcome> Function(MediaListItem item)
  onBeginPlaybackSession; // начать просмотр/прослушивание: сервер выдаёт ссылку и с какой секунды продолжить
  final void Function({
    required int positionSeconds,
    required int? durationSeconds,
    required bool isPlaying,
    bool isCompleted,
  })
  onPlaybackProgressChanged; // сообщить наружу: на какой секунде сейчас воспроизведение (чтобы запомнить на сервере)
  final Future<void> Function() onPausePlaybackSession; // поставить на паузу и зафиксировать место остановки на сервере
  final Future<void> Function() onCompletePlaybackSession; // дошли до конца ролика или главы — можно закрыть сессию «нормально»
  final Future<void> Function() onFlushPlaybackSession; // перед закрытием экрана — отправить накопленное, чтобы ничего не потерять
  final void Function() onEndPlaybackSession; // полностью выйти из режима «смотрю/слушаю» внутри приложения
  final double playbackSpeed; // как быстро сейчас идёт звук или видео (1.0 — обычная скорость)
  final void Function(double) onSetPlaybackSpeed; // пользователь выбрал другую скорость — сохранить выбор
  final bool pendingPlaybackSync; // есть несохранённые данные о прогрессе, которые ещё допишутся на сервер
  final Future<String?> Function(String fileId) onFetchPlaybackStreamUrl; // получить временную ссылку на файл для потокового воспроизведения
  final String? playbackError; // текст последней ошибки плеера, если что-то сломалось
  final Future<String> Function(MediaListItem item) onLoadBookContent; // скачать или собрать текст книги для экрана чтения
  final Future<void> Function(String mediaItemId) onRecordMediaItemView;
  final void Function(String mediaItemId) onMarkItemViewed; // пользователь открыл произведение — можно учесть «просмотрено»
  final VoidCallback onOpenSearchTab; // нажали поле поиска — открыть отдельный экран поиска и фильтров
  final Future<List<MediaFileSummary>> Function(String mediaItemId)
  onFetchMediaFiles; // список файлов на сервере, которые прикреплены к этому произведению
  final Future<void> Function({
    required String mediaItemId,
    required String fileId,
  })
  onBindMainMediaFile; // сказать серверу: вот этот файл считать основным для просмотра/прослушивания
  final Future<void> Function({
    required String mediaItemId,
    required MediaUploadPayload uploadPayload,
  })
  onUploadAndBindMainMediaFile; // загрузить новый файл с телефона и сразу сделать его основным

  final Future<MediaProgress> Function(String mediaItemId) onFetchMediaProgress;
  final Future<MediaProgress> Function({
    required String mediaItemId,
    required int stars,
  })
  onSetMediaItemUserRating;
  final Future<MediaProgress> Function(String mediaItemId)
  onClearMediaItemUserRating;
  final Future<int?> Function(List<String> mediaItemIds) onFetchWorkUserRating;
  final Future<int?> Function({
    required List<String> mediaItemIds,
    required int stars,
  })
  onSetWorkUserRating;
  final Future<void> Function(List<String> mediaItemIds) onClearWorkUserRating;
  final Future<List<MediaComment>> Function(String mediaItemId)
  onFetchMediaComments;
  final Future<MediaComment> Function({
    required String mediaItemId,
    required String text,
  })
  onCreateMediaComment;
  final Future<MediaComment> Function({
    required String commentId,
    required String text,
  })
  onUpdateMediaComment;
  final Future<void> Function(String commentId) onDeleteMediaComment;
  final Future<void> Function({
    required String commentId,
    String? reason,
  })
  onReportMediaComment;
  final Future<List<MediaListItem>> Function(String author) onFetchItemsByAuthor;
  final Future<bool> Function(String mediaItemId) onAddToShelf;
  final Future<bool> Function(String mediaItemId)? onHasBookOfflineCopy;
  final Future<bool> Function(MediaListItem item)? onDownloadBookForOffline;
  final Future<void> Function({
    required String mediaItemId,
    required String filePath,
    required String filename,
    required String contentType,
  })?
  onSaveAuthorBookLocalFile;

  final bool hideLibraryControls; // если true — не показываем поиск и фильтры (например экран «только мои работы»)
  final String? emptyLibraryMessage; // свой текст, когда список пуст (вместо стандартной фразы)

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}
