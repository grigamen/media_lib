part of 'library_screen.dart';

// Вспомогательные штуки для библиотеки: как показать тип контента словами, как открыть карточку произведения,
// как собрать одну «работу» из нескольких форматов (книга + аудио), маленькие функции про картинки и жанры.

/// Сводка средней оценки по группе форматов одного произведения.
class _WorkAverageRating {
  const _WorkAverageRating({required this.average, required this.count});

  final double average;
  final int count;
}

class _ScoredWorkRecommendation {
  const _ScoredWorkRecommendation({
    required this.group,
    required this.score,
    required this.views,
    required this.rating,
  });

  final _WorkGroup group;
  final double score;
  final int views;
  final double rating;
}

/// Обложка произведения или заглушка.
Widget _mediaCoverImage(
  BuildContext context, {
  required String? coverUrl,
  BoxFit fit = BoxFit.cover,
}) =>
    MediaCoverImage(coverUrl: coverUrl, fit: fit);

/// Число просмотров для карточки в сетке (сумма по всем форматам).
Widget _libraryGridViewsLabel(BuildContext context, List<MediaListItem> items) {
  final theme = Theme.of(context);
  final count = _totalViewsForWorkGroup(items);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.visibility_outlined,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 4),
      Text(
        "$count",
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

/// Подпись рейтинга для карточки в сетке: «4.5 (12)» или «без рейтинга».
Widget _libraryGridRatingLabel(
  BuildContext context,
  _WorkAverageRating? averageRating,
) {
  final theme = Theme.of(context);
  if (averageRating == null) {
    return Text(
      "без рейтинга",
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
  return Row(
    children: [
      Icon(Icons.star, size: 16, color: Colors.amber.shade700),
      const SizedBox(width: 4),
      Text(
        "${averageRating.average.toStringAsFixed(1)} "
        "(${averageRating.count})",
        style: theme.textTheme.labelMedium,
      ),
    ],
  );
}

/// Средняя оценка в шапке карточки произведения.
Widget _workAverageRatingHeader(
  BuildContext context,
  List<MediaListItem> variants,
) {
  final theme = Theme.of(context);
  final summary = _averageRatingForWorkGroup(variants);
  if (summary == null) {
    return Text(
      "без рейтинга",
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        summary.average.toStringAsFixed(1),
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(width: 4),
      Icon(Icons.star, size: 20, color: Colors.amber.shade700),
      const SizedBox(width: 4),
      Text(
        "(${summary.count})",
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

/// Сумма просмотров по всем форматам одного произведения.
int _totalViewsForWorkGroup(List<MediaListItem> items) {
  var total = 0;
  for (final item in items) {
    total += item.viewsCount;
  }
  return total;
}

String _formatViewsCount(int count) {
  final n = count.abs();
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 14) {
    return "$n просмотров";
  }
  if (mod10 == 1) {
    return "$n просмотр";
  }
  if (mod10 >= 2 && mod10 <= 4) {
    return "$n просмотра";
  }
  return "$n просмотров";
}

/// Взвешенное среднее по всем форматам (книга + аудио + видео) и суммарное число оценок.
bool _matchesBound(double value, LibraryBoundCompare compare, double bound) {
  return switch (compare) {
    LibraryBoundCompare.greater => value > bound,
    LibraryBoundCompare.less => value < bound,
  };
}

bool _workGroupMatchesRatingCriteria(
  _WorkGroup group,
  LibraryRatingCriteria criteria,
) {
  final summary = _averageRatingForWorkGroup(group.groupItems);
  switch (criteria.presence) {
    case LibraryRatingPresence.any:
      break;
    case LibraryRatingPresence.withRating:
      if (summary == null) {
        return false;
      }
    case LibraryRatingPresence.withoutRating:
      if (summary != null) {
        return false;
      }
  }
  final compare = criteria.boundCompare;
  final bound = criteria.boundValue;
  if (compare != null && bound != null) {
    if (summary == null) {
      return false;
    }
    if (!_matchesBound(summary.average, compare, bound)) {
      return false;
    }
  }
  return true;
}

bool _workGroupMatchesViewsCriteria(
  _WorkGroup group,
  LibraryViewsCriteria criteria,
) {
  final views = _totalViewsForWorkGroup(group.groupItems);
  switch (criteria.presence) {
    case LibraryViewsPresence.any:
      break;
    case LibraryViewsPresence.withViews:
      if (views <= 0) {
        return false;
      }
    case LibraryViewsPresence.withoutViews:
      if (views > 0) {
        return false;
      }
  }
  final compare = criteria.boundCompare;
  final bound = criteria.boundValue;
  if (compare != null && bound != null) {
    if (!_matchesBound(views.toDouble(), compare, bound.toDouble())) {
      return false;
    }
  }
  return true;
}

List<_WorkGroup> _filterWorkGroups(
  List<_WorkGroup> groups, {
  required LibraryRatingCriteria ratingCriteria,
  required LibraryViewsCriteria viewsCriteria,
}) {
  return groups
      .where(
        (group) =>
            _workGroupMatchesRatingCriteria(group, ratingCriteria) &&
            _workGroupMatchesViewsCriteria(group, viewsCriteria),
      )
      .toList(growable: false);
}

_WorkAverageRating? _averageRatingForWorkGroup(List<MediaListItem> items) {
  var weightedSum = 0.0;
  var totalCount = 0;
  for (final item in items) {
    final avg = item.averageRating;
    final count = item.ratingsCount;
    if (avg != null && count > 0) {
      weightedSum += avg * count;
      totalCount += count;
    }
  }
  if (totalCount == 0) {
    return null;
  }
  return _WorkAverageRating(
    average: weightedSum / totalCount,
    count: totalCount,
  );
}

int _compareWorkGroupTitle(_WorkGroup a, _WorkGroup b) {
  final byTitle = a.displayTitle.toLowerCase().compareTo(
    b.displayTitle.toLowerCase(),
  );
  if (byTitle != 0) {
    return byTitle;
  }
  return a.displayAuthor.toLowerCase().compareTo(b.displayAuthor.toLowerCase());
}

String _workGroupKeyFromTitleAuthor({
  required String title,
  required String? author,
}) {
  return "${title.trim().toLowerCase()}::${(author ?? "").trim().toLowerCase()}";
}

String _workGroupKeyFromItem(MediaListItem item) {
  return _workGroupKeyFromTitleAuthor(title: item.title, author: item.author);
}

Set<String> _normalizedGenresForItems(List<MediaListItem> items) {
  final genres = <String>{};
  for (final item in items) {
    for (final raw in item.genres ?? const <String>[]) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        genres.add(normalized);
      }
    }
  }
  return genres;
}

List<_WorkGroup> _buildRecommendedWorkGroups({
  required List<MediaListItem> currentGroupItems,
  required List<MediaListItem> recommendationSourceItems,
  int limit = 8,
}) {
  if (currentGroupItems.isEmpty || recommendationSourceItems.isEmpty) {
    return const <_WorkGroup>[];
  }

  final currentGroupKey = _workGroupKeyFromItem(currentGroupItems.first);
  final currentGenres = _normalizedGenresForItems(currentGroupItems);
  final currentAuthorIds = currentGroupItems
      .map((item) => item.authorId?.trim() ?? "")
      .where((id) => id.isNotEmpty)
      .map((id) => id.toLowerCase())
      .toSet();
  final currentAuthors = currentGroupItems
      .map((item) => (item.author ?? "").trim().toLowerCase())
      .where((name) => name.isNotEmpty)
      .toSet();
  final currentRating = _averageRatingForWorkGroup(currentGroupItems)?.average;

  final groupedCandidates = <String, List<MediaListItem>>{};
  for (final item in recommendationSourceItems) {
    if (item.id.isEmpty || item.id.startsWith("demo-")) {
      continue;
    }
    final key = _workGroupKeyFromItem(item);
    if (key == currentGroupKey) {
      continue;
    }
    groupedCandidates.putIfAbsent(key, () => <MediaListItem>[]).add(item);
  }

  final scored = <_ScoredWorkRecommendation>[];
  for (final groupItems in groupedCandidates.values) {
    if (groupItems.isEmpty) {
      continue;
    }
    final group = _WorkGroup(groupItems: groupItems);
    final groupGenres = _normalizedGenresForItems(group.groupItems);
    final genreOverlap = currentGenres.intersection(groupGenres).length;

    final groupAuthorIds = group.groupItems
        .map((item) => item.authorId?.trim() ?? "")
        .where((id) => id.isNotEmpty)
        .map((id) => id.toLowerCase())
        .toSet();
    final groupAuthors = group.groupItems
        .map((item) => (item.author ?? "").trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();

    final hasSameAuthorId =
        currentAuthorIds.isNotEmpty && currentAuthorIds.intersection(groupAuthorIds).isNotEmpty;
    final hasSameAuthorName =
        currentAuthors.isNotEmpty && currentAuthors.intersection(groupAuthors).isNotEmpty;

    var score = 0.0;
    if (hasSameAuthorId) {
      score += 120;
    } else if (hasSameAuthorName) {
      score += 90;
    }
    score += genreOverlap * 18;

    final rating = _averageRatingForWorkGroup(group.groupItems)?.average;
    if (rating != null && currentRating != null) {
      final diff = (currentRating - rating).abs().clamp(0.0, 5.0);
      score += (5 - diff) * 6;
    } else if (rating != null) {
      score += rating;
    }

    final views = _totalViewsForWorkGroup(group.groupItems);
    if (views > 0) {
      score += views.clamp(0, 5000) / 5000 * 8;
    }

    scored.add(
      _ScoredWorkRecommendation(
        group: group,
        score: score,
        views: views,
        rating: rating ?? -1,
      ),
    );
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) {
      return byScore;
    }
    final byViews = b.views.compareTo(a.views);
    if (byViews != 0) {
      return byViews;
    }
    final byRating = b.rating.compareTo(a.rating);
    if (byRating != 0) {
      return byRating;
    }
    return _compareWorkGroupTitle(a.group, b.group);
  });

  return scored
      .take(limit.clamp(1, 20))
      .map((item) => item.group)
      .toList(growable: false);
}

double _workGroupRatingSortKey(_WorkGroup group) {
  return _averageRatingForWorkGroup(group.groupItems)?.average ?? -1;
}

void _sortWorkGroups(
  List<_WorkGroup> groups, {
  required LibrarySortField field,
  required bool descending,
}) {
  int primaryCompare(_WorkGroup a, _WorkGroup b) {
    switch (field) {
      case LibrarySortField.title:
        return _compareWorkGroupTitle(a, b);
      case LibrarySortField.rating:
        return _workGroupRatingSortKey(
          a,
        ).compareTo(_workGroupRatingSortKey(b));
      case LibrarySortField.views:
        return _totalViewsForWorkGroup(
          a.groupItems,
        ).compareTo(_totalViewsForWorkGroup(b.groupItems));
    }
  }

  groups.sort((a, b) {
    var result = primaryCompare(a, b);
    if (result != 0) {
      if (descending) {
        result = -result;
      }
    } else {
      result = _compareWorkGroupTitle(a, b);
    }
    return result;
  });
}

/// Как показать пользователю тип контента обычным словом («Книга», а не внутренний код).
String _labelForType(String type) {
  switch (type) {
    case "book":
      return "Книга";
    case "audiobook":
      return "Аудиокнига";
    case "video":
      return "Видео";
    default:
      return type;
  }
}

/// Убираем повторы жанра в разном написании — оставляем один раз, без учёта заглавных букв.
List<String> _uniqueGenres(Iterable<String> genres) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in genres) {
    final genre = raw.trim();
    if (genre.isEmpty) {
      continue;
    }
    final key = genre.toLowerCase();
    if (seen.contains(key)) {
      continue;
    }
    seen.add(key);
    result.add(genre);
  }
  return result;
}

/// По имени файла картинки угадываем формат (jpeg, png и т.д.) — нужно при загрузке обложки.
String? _inferImageMimeFromFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
    return "image/jpeg";
  }
  if (lower.endsWith(".png")) {
    return "image/png";
  }
  if (lower.endsWith(".webp")) {
    return "image/webp";
  }
  return null;
}

/// Какую вкладку формата открыть: явный id, единственный фильтр по типу или единственный вариант в группе.
String? resolveInitialMediaItemIdForGroup({
  required List<MediaListItem> groupItems,
  List<String> selectedTypes = const [],
  String? preferredMediaItemId,
}) {
  if (groupItems.isEmpty) {
    return null;
  }
  if (preferredMediaItemId != null &&
      groupItems.any((item) => item.id == preferredMediaItemId)) {
    return preferredMediaItemId;
  }
  final typeFilter = selectedTypes.toSet();
  if (typeFilter.length == 1) {
    for (final item in groupItems) {
      if (item.type == typeFilter.first) {
        return item.id;
      }
    }
  }
  if (typeFilter.isNotEmpty) {
    for (final item in groupItems) {
      if (typeFilter.contains(item.type)) {
        return item.id;
      }
    }
  }
  if (groupItems.length == 1) {
    return groupItems.first.id;
  }
  return groupItems.first.id;
}

/// Открывает большой экран одного произведения и передаёт туда все нужные «что сделать по нажатию» из родителя.
Future<void> openMediaItemDetailsPage({
  required BuildContext context,
  required String? currentUserId,
  required bool isAdminUser,
  required List<MediaListItem> groupItems,
  required List<MediaListItem> recommendationSourceItems,
  String? initialMediaItemId,
  required List<String> availableGenres,
  required Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks,
  required Future<MediaListItem?> Function(String mediaItemId) onLoadItemById,
  required Future<MediaListItem> Function({
    required String mediaItemId,
    required String type,
    required String title,
    String? author,
    String? authorId,
    bool? clearAuthor,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    MediaUploadPayload? uploadPayload,
    String? description,
  })
  onUpdateItem,
  required Future<MediaListItem> Function({
    required String sourceMediaItemId,
    required String type,
    required String title,
    String? author,
    String? authorId,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    String? description,
    MediaUploadPayload? uploadPayload,
  })
  onAddFormatToWork,
  required Future<PlaybackSessionOutcome> Function(MediaListItem item)
  onBeginPlaybackSession,
  required void Function({
    required int positionSeconds,
    required int? durationSeconds,
    required bool isPlaying,
    bool isCompleted,
  })
  onPlaybackProgressChanged,
  required Future<void> Function() onPausePlaybackSession,
  required Future<void> Function() onCompletePlaybackSession,
  required Future<void> Function() onFlushPlaybackSession,
  required void Function() onEndPlaybackSession,
  required double playbackSpeed,
  required void Function(double) onSetPlaybackSpeed,
  required bool pendingPlaybackSync,
  required Future<String?> Function(String fileId) onFetchPlaybackStreamUrl,
  required String? playbackError,
  required Future<String> Function(MediaListItem item) onLoadBookContent,
  required Future<void> Function(String mediaItemId) onRecordMediaItemView,
  required void Function(String mediaItemId) onMarkItemViewed,
  required Future<List<MediaFileSummary>> Function(String mediaItemId)
  onFetchMediaFiles,
  required Future<void> Function({
    required String mediaItemId,
    required String fileId,
  })
  onBindMainMediaFile,
  required Future<void> Function({
    required String mediaItemId,
    required MediaUploadPayload uploadPayload,
  })
  onUploadAndBindMainMediaFile,
  required Future<MediaProgress> Function(String mediaItemId) onFetchMediaProgress,
  required Future<MediaProgress> Function({
    required String mediaItemId,
    required int stars,
  })
  onSetMediaItemUserRating,
  required Future<MediaProgress> Function(String mediaItemId)
  onClearMediaItemUserRating,
  required Future<int?> Function(List<String> mediaItemIds) onFetchWorkUserRating,
  required Future<int?> Function({
    required List<String> mediaItemIds,
    required int stars,
  })
  onSetWorkUserRating,
  required Future<void> Function(List<String> mediaItemIds)
  onClearWorkUserRating,
  required Future<List<MediaComment>> Function(String mediaItemId)
  onFetchMediaComments,
  required Future<MediaComment> Function({
    required String mediaItemId,
    required String text,
  })
  onCreateMediaComment,
  required Future<MediaComment> Function({
    required String commentId,
    required String text,
  })
  onUpdateMediaComment,
  required Future<void> Function(String commentId) onDeleteMediaComment,
  required Future<void> Function({
    required String commentId,
    String? reason,
  })
  onReportMediaComment,
  required Future<List<MediaListItem>> Function({
    required String authorName,
    String? authorId,
  })
  onFetchItemsByAuthor,
  required Future<void> Function({
    required String authorName,
    String? authorId,
  })
  onOpenAuthorWorks,
  required Future<List<MediaAuthor>> Function(String query) onSearchAuthors,
  required Future<MediaAuthor> Function(String name) onCreateAuthor,
  required Future<bool> Function(String mediaItemId) onAddToShelf,
  Future<bool> Function(String mediaItemId)? onHasBookOfflineCopy,
  Future<bool> Function(MediaListItem item)? onDownloadBookForOffline,
  Future<void> Function({
    required String mediaItemId,
    required String filePath,
    required String filename,
    required String contentType,
  })?
  onSaveAuthorBookLocalFile,
}) {
  final resolvedInitialId = resolveInitialMediaItemIdForGroup(
    groupItems: groupItems,
    preferredMediaItemId: initialMediaItemId,
  );
  if (resolvedInitialId != null) {
    onMarkItemViewed(resolvedInitialId);
  }
  final group = _WorkGroup(groupItems: groupItems);
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder:
          (_) => _MediaItemDetailsPage(
            currentUserId: currentUserId,
            isAdminUser: isAdminUser,
            group: group,
            recommendationSourceItems: recommendationSourceItems,
            initialMediaItemId: resolvedInitialId,
            availableGenres: availableGenres,
            onLoadLinks: onLoadLinks,
            onLoadItemById: onLoadItemById,
            onUpdateItem: onUpdateItem,
            onAddFormatToWork: onAddFormatToWork,
            onBeginPlaybackSession: onBeginPlaybackSession,
            onPlaybackProgressChanged: onPlaybackProgressChanged,
            onPausePlaybackSession: onPausePlaybackSession,
            onCompletePlaybackSession: onCompletePlaybackSession,
            onFlushPlaybackSession: onFlushPlaybackSession,
            onEndPlaybackSession: onEndPlaybackSession,
            playbackSpeed: playbackSpeed,
            onSetPlaybackSpeed: onSetPlaybackSpeed,
            pendingPlaybackSync: pendingPlaybackSync,
            onFetchPlaybackStreamUrl: onFetchPlaybackStreamUrl,
            playbackError: playbackError,
            onLoadBookContent: onLoadBookContent,
            onRecordMediaItemView: onRecordMediaItemView,
            onFetchMediaFiles: onFetchMediaFiles,
            onBindMainMediaFile: onBindMainMediaFile,
            onUploadAndBindMainMediaFile: onUploadAndBindMainMediaFile,
            onFetchMediaProgress: onFetchMediaProgress,
            onSetMediaItemUserRating: onSetMediaItemUserRating,
            onClearMediaItemUserRating: onClearMediaItemUserRating,
            onFetchWorkUserRating: onFetchWorkUserRating,
            onSetWorkUserRating: onSetWorkUserRating,
            onClearWorkUserRating: onClearWorkUserRating,
            onFetchMediaComments: onFetchMediaComments,
            onCreateMediaComment: onCreateMediaComment,
            onUpdateMediaComment: onUpdateMediaComment,
            onDeleteMediaComment: onDeleteMediaComment,
            onReportMediaComment: onReportMediaComment,
            onFetchItemsByAuthor: onFetchItemsByAuthor,
            onOpenAuthorWorks: onOpenAuthorWorks,
            onSearchAuthors: onSearchAuthors,
            onCreateAuthor: onCreateAuthor,
            onAddToShelf: onAddToShelf,
            onHasBookOfflineCopy: onHasBookOfflineCopy,
            onDownloadBookForOffline: onDownloadBookForOffline,
            onSaveAuthorBookLocalFile: onSaveAuthorBookLocalFile,
          ),
    ),
  );
}

/// То же открытие карточки, но проще вызвать из приложения: внутри подставляются готовые действия из общего состояния.
Future<void> openMediaItemDetailsForAppState({
  required BuildContext context,
  required AppState state,
  required List<MediaListItem> groupItems,
  String? initialMediaItemId,
}) {
  return openMediaItemDetailsPage(
    context: context,
    currentUserId: state.currentUserId,
    isAdminUser: state.isAdminUser,
    groupItems: groupItems,
    recommendationSourceItems: state.items,
    initialMediaItemId: initialMediaItemId,
    availableGenres: state.availableGenres,
    onLoadLinks: state.fetchLinksForItem,
    onLoadItemById: state.fetchMediaItemById,
    onUpdateItem:
        ({
          required mediaItemId,
          required type,
          required title,
          author,
          authorId,
          clearAuthor = false,
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
          authorId: authorId,
          clearAuthor: clearAuthor ?? false,
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
          authorId,
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
          authorId: authorId,
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
    onFetchPlaybackStreamUrl: state.fetchPlaybackStreamUrl,
    playbackError: state.playbackError,
    onLoadBookContent: state.loadBookContent,
    onRecordMediaItemView: state.recordMediaItemView,
    onMarkItemViewed: state.markItemViewed,
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
    onFetchMediaComments: state.fetchMediaCommentsForItem,
    onCreateMediaComment:
        ({required String mediaItemId, required String text}) =>
            state.createMediaComment(mediaItemId: mediaItemId, text: text),
    onUpdateMediaComment:
        ({required String commentId, required String text}) =>
            state.updateMediaComment(commentId: commentId, text: text),
    onDeleteMediaComment: state.deleteMediaComment,
    onReportMediaComment:
        ({required commentId, reason}) => state.reportMediaComment(
          commentId: commentId,
          reason: reason,
        ),
    onFetchItemsByAuthor:
        ({required authorName, authorId}) => state.fetchMediaItemsByAuthor(
          authorName: authorName,
          authorId: authorId,
        ),
    onOpenAuthorWorks:
        ({required authorName, authorId}) => openAuthorWorksScreen(
          context: context,
          state: state,
          authorName: authorName,
          authorId: authorId,
        ),
    onSearchAuthors: state.searchAuthors,
    onCreateAuthor: state.createAuthor,
    onAddToShelf:
        (mediaItemId) => showAddToShelfDialog(
          context: context,
          state: state,
          mediaItemId: mediaItemId,
        ),
    onHasBookOfflineCopy: state.hasBookOfflineCopy,
    onDownloadBookForOffline: state.downloadBookForOffline,
    onSaveAuthorBookLocalFile:
        ({
          required String mediaItemId,
          required String filePath,
          required String filename,
          required String contentType,
        }) => state.saveAuthorBookLocalFile(
          mediaItemId: mediaItemId,
          filePath: filePath,
          filename: filename,
          contentType: contentType,
        ),
  );
}

/// Ссылка на автора в шапке карточки произведения.
MediaAuthor? _authorFromItem(MediaListItem item) {
  final name = item.author?.trim();
  final id = item.authorId?.trim();
  if (name == null || name.isEmpty) {
    return null;
  }
  if (id != null && id.isNotEmpty) {
    return MediaAuthor(id: id, name: name);
  }
  return null;
}

Widget _workAuthorLink(
  BuildContext context, {
  required String authorName,
  required VoidCallback? onTap,
}) {
  final theme = Theme.of(context);
  final style = theme.textTheme.bodyMedium?.copyWith(
    color: onTap == null ? null : theme.colorScheme.primary,
    decoration: onTap == null ? null : TextDecoration.underline,
  );
  if (onTap == null) {
    return Text(authorName, style: style);
  }
  return InkWell(
    onTap: onTap,
    child: Text(authorName, style: style),
  );
}

/// Одно произведение для сетки: под одним названием и автором может быть книга, аудио и видео — здесь они собраны вместе.
class _WorkGroup {
  _WorkGroup({required this.groupItems});

  final List<MediaListItem> groupItems;

  MediaListItem get primaryItem => groupItems.first;
  String get displayTitle => primaryItem.title;
  String get displayAuthor => primaryItem.author ?? "";
  List<String> get types =>
      groupItems.map((item) => item.type).toSet().toList(growable: false)
        ..sort();

  /// Плашка на обложке: «на проверке» или «отклонено», если среди ваших вариантов есть такие статусы.
  String? ownerModerationLabel(String? currentUserId) {
    if (currentUserId == null) {
      return null;
    }
    final owned =
        groupItems.where((i) => i.userId == currentUserId).toList();
    if (owned.isEmpty) {
      return null;
    }
    if (owned.any((i) => i.moderationStatus == "rejected")) {
      return "Отклонено";
    }
    if (owned.any((i) => i.moderationStatus == "pending")) {
      return "На модерации";
    }
    return null;
  }
}
