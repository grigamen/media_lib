part of 'library_screen.dart';

// Сборка большого экрана: вкладки по форматам, текст, кнопки владельца, чтение книги или плеер.

/// Рисует вкладки, описание и панели действий, опираясь на набор общих фрагментов кода (миксины).
class _MediaItemDetailsPageState extends State<_MediaItemDetailsPage>
    with
        SingleTickerProviderStateMixin,
        _MediaItemDetailsStateFields,
        _MediaItemDetailsLifecycleMixin,
        _MediaItemDetailsEditDialogsMixin,
        _MediaItemDetailsAddFormatDialogsMixin {
  @override
  void initState() {
    super.initState();
    _variants =
        List<MediaListItem>.from(
          widget.group.groupItems,
        ).where(_shouldShowVariantInWorkGroup).toList();
    _focusedMediaItemId = widget.initialMediaItemId;
    if (_focusedMediaItemId == null && _variants.isNotEmpty) {
      _focusedMediaItemId = _variants.first.id;
    }
    _tabController = TabController(
      length: _variants.isEmpty ? 1 : _variants.length,
      vsync: this,
      initialIndex: _variantIndexForFocused(),
    );
    _tabController.addListener(_onTabIndexChanged);
    _loadLinkedVariants();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabIndexChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// Полоска сверху: стрелка «назад» и название произведения.
  Widget _workDetailsHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: "Назад",
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(child: Text(title, style: theme.textTheme.headlineSmall)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.group.displayTitle;
    if (_variants.isEmpty) {
      return Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _workDetailsHeader(context, title),
            const Expanded(
              child: Center(child: Text("Нет доступных форм произведения")),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _workDetailsHeader(context, title),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                final selectedIndex = _tabController.index.clamp(
                  0,
                  _variants.length - 1,
                );
                final activeItem = _variants[selectedIndex];
                      final activeAuthor =
                          activeItem.author?.trim().isNotEmpty == true
                              ? activeItem.author!.trim()
                              : "Не указан";
                      final activeGenres = _uniqueGenres([
                        ...?activeItem.genres,
                      ]);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        height: 160,
                                        width: 110,
                                        child: _mediaCoverImage(
                                          context,
                                          coverUrl: activeItem.coverUrl,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activeItem.title,
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.headlineSmall,
                                          ),
                                      const SizedBox(height: 4),
                                      _workAuthorLink(
                                        context,
                                        authorName: activeAuthor,
                                        onTap:
                                            activeAuthor == "Не указан"
                                                ? null
                                                : () => _showOtherWorksByAuthor(
                                                  activeAuthor,
                                                ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          _workAverageRatingHeader(
                                            context,
                                            _variants,
                                          ),
                                          if (widget.currentUserId != null) ...[
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                              child: Text(
                                                "|",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                  color:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .outline,
                                                ),
                                              ),
                                            ),
                                            _WorkUserRatingBar(
                                              key: ValueKey(
                                                _rateableVariantIds.join("|"),
                                              ),
                                              compact: true,
                                              onLoadStars:
                                                  () =>
                                                      widget
                                                          .onFetchWorkUserRating(
                                                        _rateableVariantIds,
                                                      ),
                                              onSetStars:
                                                  (stars) =>
                                                      widget.onSetWorkUserRating(
                                                        mediaItemIds:
                                                            _rateableVariantIds,
                                                        stars: stars,
                                                      ),
                                              onClearStars:
                                                  () =>
                                                      widget
                                                          .onClearWorkUserRating(
                                                        _rateableVariantIds,
                                                      ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (activeGenres.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: activeGenres
                                                  .map(
                                                    (genre) => Chip(
                                                      label: Text(genre),
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                            ),
                                          ],
                                          if (_isLoadingLinked) ...[
                                            const SizedBox(height: 6),
                                            const Text(
                                              "Загружаем связанные формы произведения...",
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.currentUserId != null &&
                                    !activeItem.id.startsWith("demo-")) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final added = await widget.onAddToShelf(
                                        activeItem.id,
                                      );
                                      if (!added || !context.mounted) {
                                        return;
                                      }
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (!context.mounted) {
                                              return;
                                            }
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Добавлено на полку",
                                                ),
                                              ),
                                            );
                                          });
                                    },
                                    icon: const Icon(Icons.bookmark_add_outlined),
                                    label: const Text("На полку"),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabs: _variants
                                .map(
                                  (item) => Tab(text: _labelForType(item.type)),
                                )
                                .toList(growable: false),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: _variants
                                  .map(
                                    (item) => ListView(
                                      key: ValueKey<String>(item.id),
                                      padding: const EdgeInsets.all(16),
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            color:
                                                Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerLow,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Описание",
                                                      style:
                                                          Theme.of(
                                                            context,
                                                          ).textTheme.labelLarge,
                                                    ),
                                                    const Spacer(),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .visibility_outlined,
                                                          size: 18,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          _formatViewsCount(
                                                            item.viewsCount,
                                                          ),
                                                          style:
                                                              Theme.of(
                                                                    context,
                                                                  )
                                                                  .textTheme
                                                                  .bodyMedium,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  item
                                                              .description
                                                              ?.isNotEmpty ==
                                                          true
                                                      ? item.description!
                                                      : "Описание отсутствует",
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (widget.currentUserId != null &&
                                            item.userId ==
                                                widget.currentUserId &&
                                            !item.id.startsWith("demo-")) ...[
                                          const SizedBox(height: 16),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                if (_ownerMainFileSectionOpen
                                                    .contains(item.id)) {
                                                  _ownerMainFileSectionOpen
                                                      .remove(item.id);
                                                } else {
                                                  _ownerMainFileSectionOpen.add(
                                                    item.id,
                                                  );
                                                }
                                              });
                                            },
                                            icon: Icon(
                                              _ownerMainFileSectionOpen
                                                      .contains(item.id)
                                                  ? Icons.expand_less
                                                  : Icons.folder_open_outlined,
                                            ),
                                            label: Text(
                                              _ownerMainFileSectionOpen
                                                      .contains(item.id)
                                                  ? "Скрыть основной файл контента"
                                                  : "Основной файл контента",
                                            ),
                                          ),
                                          if (_ownerMainFileSectionOpen
                                              .contains(item.id)) ...[
                                            const SizedBox(height: 12),
                                            _OwnerMainMediaFileCard(
                                              item: item,
                                              onFetchFiles:
                                                  widget.onFetchMediaFiles,
                                              onBindFile:
                                                  widget.onBindMainMediaFile,
                                              onUploadAndBind:
                                                  widget
                                                      .onUploadAndBindMainMediaFile,
                                              onVariantRefreshed:
                                                  () =>
                                                      _refreshVariant(item.id),
                                              fallbackContentType:
                                                  _fallbackContentType,
                                              inferContentTypeFromName:
                                                  _inferContentTypeFromName,
                                              isFileCompatibleWithType:
                                                  _isFileCompatibleWithType,
                                            ),
                                          ],
                                        ],
                                        if (item.type == "book") ...[
                                          const SizedBox(height: 16),
                                          _BookReadLaunchPanel(
                                            item: item,
                                            isOwner:
                                                widget.currentUserId != null &&
                                                item.userId ==
                                                    widget.currentUserId,
                                            canUseOffline:
                                                widget.currentUserId != null &&
                                                !item.id.startsWith("demo-") &&
                                                !kIsWeb,
                                            onOpenReader:
                                                () => _openBookReader(item),
                                            onDownloadForOffline:
                                                widget.onDownloadBookForOffline ==
                                                        null
                                                    ? null
                                                    : () => widget
                                                        .onDownloadBookForOffline!(
                                                      item,
                                                    ),
                                            onPickLocalFile:
                                                widget.currentUserId != null &&
                                                        item.userId ==
                                                            widget
                                                                .currentUserId
                                                    ? () =>
                                                        _pickAuthorBookLocalFile(
                                                          item,
                                                        )
                                                    : null,
                                            checkHasOfflineCopy:
                                                widget.onHasBookOfflineCopy ==
                                                        null
                                                    ? null
                                                    : () => widget
                                                        .onHasBookOfflineCopy!(
                                                      item.id,
                                                    ),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            if (widget.currentUserId != null &&
                                                item.userId ==
                                                    widget.currentUserId)
                                              OutlinedButton.icon(
                                                onPressed:
                                                    () =>
                                                        _showEditVariantDialog(
                                                          item,
                                                        ),
                                                icon: const Icon(Icons.edit),
                                                label: const Text(
                                                  "Редактировать",
                                                ),
                                              ),
                                            FilledButton.icon(
                                              onPressed: _showAddFormatDialog,
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                              ),
                                              label: const Text(
                                                "Добавить формат",
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (item.type == "audiobook" ||
                                            item.type == "video") ...[
                                          const SizedBox(height: 16),
                                          _PlayableMediaPanel(
                                            item: item,
                                            onBeginPlaybackSession:
                                                _beginPlaybackSessionForVariant,
                                            onRecordMediaItemView: (mediaItemId) async {
                                              await widget.onRecordMediaItemView(
                                                mediaItemId,
                                              );
                                              await _refreshVariant(mediaItemId);
                                            },
                                            onPlaybackProgressChanged:
                                                widget
                                                    .onPlaybackProgressChanged,
                                            onPausePlaybackSession:
                                                widget.onPausePlaybackSession,
                                            onCompletePlaybackSession:
                                                widget
                                                    .onCompletePlaybackSession,
                                            onFlushPlaybackSession:
                                                widget.onFlushPlaybackSession,
                                            onEndPlaybackSession:
                                                widget.onEndPlaybackSession,
                                            playbackSpeed: widget.playbackSpeed,
                                            onSetPlaybackSpeed:
                                                widget.onSetPlaybackSpeed,
                                            pendingPlaybackSync:
                                                widget.pendingPlaybackSync,
                                            playbackError: widget.playbackError,
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                        _MediaCommentsSection(
                                          key: ValueKey("comments-${item.id}"),
                                          mediaItemId: item.id,
                                          mediaItemOwnerId: item.userId,
                                          currentUserId: widget.currentUserId,
                                          isAdminUser: widget.isAdminUser,
                                          onLoadComments:
                                              widget.onFetchMediaComments,
                                          onCreateComment:
                                              widget.onCreateMediaComment,
                                          onUpdateComment:
                                              widget.onUpdateMediaComment,
                                          onDeleteComment:
                                              widget.onDeleteMediaComment,
                                          onReportComment:
                                              widget.onReportMediaComment,
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _rateableVariantIds => _variants
      .map((item) => item.id)
      .where((id) => id.isNotEmpty)
      .toList(growable: false);

  Future<void> _showOtherWorksByAuthor(String authorName) async {
    final excludeWorkKey = mediaWorkGroupKey(_variants.first);
    final items = await widget.onFetchItemsByAuthor(authorName);
    if (!mounted) {
      return;
    }
    final groups =
        _buildWorkGroupsFromItems(items)
            .where((group) => mediaWorkGroupKey(group.primaryItem) != excludeWorkKey)
            .toList(growable: false);
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final listHeight =
            (MediaQuery.sizeOf(sheetContext).height * 0.55).clamp(160.0, 480.0);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Другие произведения автора",
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  authorName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      "Других произведений этого автора не найдено.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  SizedBox(
                    height: listHeight,
                    child: ListView.separated(
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final formatLabels =
                            group.types
                                .map(_labelForType)
                                .toList(growable: false);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 64,
                              child: _mediaCoverImage(
                                context,
                                coverUrl: group.primaryItem.coverUrl,
                              ),
                            ),
                          ),
                          title: Text(group.displayTitle),
                          subtitle: Text(formatLabels.join(", ")),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            unawaited(_openWorkGroup(group.groupItems));
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openWorkGroup(List<MediaListItem> groupItems) async {
    if (groupItems.isEmpty || !mounted) {
      return;
    }
    await openMediaItemDetailsPage(
      context: context,
      currentUserId: widget.currentUserId,
      isAdminUser: widget.isAdminUser,
      groupItems: groupItems,
      initialMediaItemId: groupItems.first.id,
      availableGenres: widget.availableGenres,
      onLoadLinks: widget.onLoadLinks,
      onLoadItemById: widget.onLoadItemById,
      onUpdateItem: widget.onUpdateItem,
      onAddFormatToWork: widget.onAddFormatToWork,
      onBeginPlaybackSession: widget.onBeginPlaybackSession,
      onPlaybackProgressChanged: widget.onPlaybackProgressChanged,
      onPausePlaybackSession: widget.onPausePlaybackSession,
      onCompletePlaybackSession: widget.onCompletePlaybackSession,
      onFlushPlaybackSession: widget.onFlushPlaybackSession,
      onEndPlaybackSession: widget.onEndPlaybackSession,
      playbackSpeed: widget.playbackSpeed,
      onSetPlaybackSpeed: widget.onSetPlaybackSpeed,
      pendingPlaybackSync: widget.pendingPlaybackSync,
      onFetchPlaybackStreamUrl: widget.onFetchPlaybackStreamUrl,
      playbackError: widget.playbackError,
      onLoadBookContent: widget.onLoadBookContent,
      onRecordMediaItemView: widget.onRecordMediaItemView,
      onMarkItemViewed: (_) {},
      onFetchMediaFiles: widget.onFetchMediaFiles,
      onBindMainMediaFile: widget.onBindMainMediaFile,
      onUploadAndBindMainMediaFile: widget.onUploadAndBindMainMediaFile,
      onFetchMediaProgress: widget.onFetchMediaProgress,
      onSetMediaItemUserRating: widget.onSetMediaItemUserRating,
      onClearMediaItemUserRating: widget.onClearMediaItemUserRating,
      onFetchWorkUserRating: widget.onFetchWorkUserRating,
      onSetWorkUserRating: widget.onSetWorkUserRating,
      onClearWorkUserRating: widget.onClearWorkUserRating,
      onFetchMediaComments: widget.onFetchMediaComments,
      onCreateMediaComment: widget.onCreateMediaComment,
      onUpdateMediaComment: widget.onUpdateMediaComment,
      onDeleteMediaComment: widget.onDeleteMediaComment,
      onReportMediaComment: widget.onReportMediaComment,
      onFetchItemsByAuthor: widget.onFetchItemsByAuthor,
      onAddToShelf: widget.onAddToShelf,
      onHasBookOfflineCopy: widget.onHasBookOfflineCopy,
      onDownloadBookForOffline: widget.onDownloadBookForOffline,
      onSaveAuthorBookLocalFile: widget.onSaveAuthorBookLocalFile,
    );
  }
}

const _kUserRatingStarColor = Color(0xFF42A5F5);

/// Звёздная оценка произведения (1–5) для всех форматов работы.
class _WorkUserRatingBar extends StatefulWidget {
  const _WorkUserRatingBar({
    super.key,
    this.compact = false,
    required this.onLoadStars,
    required this.onSetStars,
    required this.onClearStars,
  });

  final bool compact;
  final Future<int?> Function() onLoadStars;
  final Future<int?> Function(int stars) onSetStars;
  final Future<void> Function() onClearStars;

  @override
  State<_WorkUserRatingBar> createState() => _WorkUserRatingBarState();
}

class _WorkUserRatingBarState extends State<_WorkUserRatingBar> {
  int? _stars;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void didUpdateWidget(covariant _WorkUserRatingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.key != widget.key) {
      unawaited(_reload());
    }
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    try {
      final stars = await widget.onLoadStars();
      if (!mounted) {
        return;
      }
      setState(() {
        _stars = stars;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
    }
  }

  Future<void> _saveStars(int n) async {
    setState(() => _busy = true);
    try {
      final stars = await widget.onSetStars(n);
      if (!mounted) {
        return;
      }
      setState(() {
        _stars = stars;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      final msg =
          e is ApiException ? e.message : "Не удалось сохранить оценку";
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _openRatingForm() async {
    if (_busy) {
      return;
    }
    var draft = _stars ?? 0;
    final result = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Ваша оценка",
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Выберите от 1 до 5 звёзд",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          IconButton(
                            tooltip: "$i из 5",
                            onPressed:
                                () => setModalState(() {
                                  draft = i;
                                }),
                            icon: Icon(
                              draft >= i ? Icons.star : Icons.star_border,
                              size: 40,
                              color:
                                  draft >= i
                                      ? _kUserRatingStarColor
                                      : theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed:
                          draft >= 1 && draft <= 5
                              ? () => Navigator.of(sheetContext).pop(draft)
                              : null,
                      child: const Text("Сохранить"),
                    ),
                    if (_stars != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(0),
                        child: const Text("Удалить оценку"),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted || result == null) {
      return;
    }
    if (result == 0) {
      await _clear();
      return;
    }
    await _saveStars(result);
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    try {
      await widget.onClearStars();
      if (!mounted) {
        return;
      }
      setState(() {
        _stars = null;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      final msg = e is ApiException ? e.message : "Не удалось сбросить оценку";
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stars = _stars;
    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (stars != null) ...[
            Text("$stars", style: theme.textTheme.titleMedium),
            Icon(Icons.star, size: 20, color: _kUserRatingStarColor),
            const SizedBox(width: 8),
          ],
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _busy ? null : _openRatingForm,
            child:
                _busy
                    ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kUserRatingStarColor,
                      ),
                    )
                    : Text(stars == null ? "Оценить" : "Изменить"),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Моя оценка", style: theme.textTheme.titleSmall),
        if (stars != null) ...[
          const SizedBox(height: 4),
          Text(
            "Ваша оценка: $stars",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _openRatingForm,
          icon:
              _busy
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Icon(stars == null ? Icons.star_outline : Icons.edit_outlined),
          label: Text(stars == null ? "Поставить оценку" : "Изменить оценку"),
        ),
      ],
    );
  }
}

class _EditCommentDialog extends StatefulWidget {
  const _EditCommentDialog({required this.initialText});

  final String initialText;

  @override
  State<_EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<_EditCommentDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Редактировать комментарий"),
      content: TextField(
        controller: _controller,
        minLines: 3,
        maxLines: 6,
        maxLength: 2000,
        decoration: const InputDecoration(
          hintText: "Ваш комментарий",
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Отмена"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text("Сохранить"),
        ),
      ],
    );
  }
}

class _ReportCommentDialog extends StatefulWidget {
  const _ReportCommentDialog();

  @override
  State<_ReportCommentDialog> createState() => _ReportCommentDialogState();
}

class _ReportCommentDialogState extends State<_ReportCommentDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Пожаловаться на комментарий"),
      content: TextField(
        controller: _controller,
        minLines: 2,
        maxLines: 5,
        maxLength: 1000,
        decoration: const InputDecoration(
          hintText: "Причина (необязательно)",
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Отмена"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text("Отправить"),
        ),
      ],
    );
  }
}

abstract class _MediaCommentsWidget extends StatefulWidget {
  const _MediaCommentsWidget({
    super.key,
    required this.mediaItemId,
    required this.mediaItemOwnerId,
    required this.currentUserId,
    required this.isAdminUser,
    required this.onLoadComments,
    required this.onCreateComment,
    required this.onUpdateComment,
    required this.onDeleteComment,
    required this.onReportComment,
  });

  final String mediaItemId;
  final String? mediaItemOwnerId;
  final String? currentUserId;
  final bool isAdminUser;
  final Future<List<MediaComment>> Function(String mediaItemId) onLoadComments;
  final Future<MediaComment> Function({
    required String mediaItemId,
    required String text,
  })
  onCreateComment;
  final Future<MediaComment> Function({
    required String commentId,
    required String text,
  })
  onUpdateComment;
  final Future<void> Function(String commentId) onDeleteComment;
  final Future<void> Function({
    required String commentId,
    String? reason,
  })
  onReportComment;
}

abstract class _MediaCommentsState<W extends _MediaCommentsWidget> extends State<W> {
  static const int previewCount = 3;

  final TextEditingController _controller = TextEditingController();
  List<MediaComment> _comments = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canComment =>
      widget.currentUserId != null && !widget.mediaItemId.startsWith("demo-");

  List<MediaComment> get _previewComments {
    if (_comments.length <= previewCount) {
      return _comments;
    }
    return _comments.sublist(_comments.length - previewCount);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final comments = await widget.onLoadComments(widget.mediaItemId);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e is ApiException ? e.message : "Не удалось загрузить комментарии";
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await widget.onCreateComment(
        mediaItemId: widget.mediaItemId,
        text: text,
      );
      if (!mounted) {
        return;
      }
      _controller.clear();
      setState(() {
        _comments = [..._comments, created];
        _saving = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      _showError(e, "Не удалось добавить комментарий");
    }
  }

  Future<void> _edit(MediaComment comment) async {
    final result = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => _EditCommentDialog(initialText: comment.text),
    );
    final text = result?.trim();
    if (text == null || text.isEmpty || text == comment.text.trim()) {
      return;
    }
    try {
      final updated = await widget.onUpdateComment(
        commentId: comment.id,
        text: text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = [
          for (final item in _comments) item.id == updated.id ? updated : item,
        ];
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e, "Не удалось обновить комментарий");
    }
  }

  Future<void> _delete(MediaComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text("Удалить комментарий?"),
            content: const Text("Это действие нельзя отменить."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text("Отмена"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text("Удалить"),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.onDeleteComment(comment.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _comments
            .where((item) => item.id != comment.id)
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e, "Не удалось удалить комментарий");
    }
  }

  Future<void> _report(MediaComment comment) async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => const _ReportCommentDialog(),
    );
    if (reason == null) {
      return;
    }
    try {
      await widget.onReportComment(
        commentId: comment.id,
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Жалоба отправлена")),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e, "Не удалось отправить жалобу");
    }
  }

  void _showError(Object error, String fallback) {
    final message = error is ApiException ? error.message : fallback;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatCommentDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return "";
    }
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, "0");
    return "${two(local.day)}.${two(local.month)}.${local.year} "
        "${two(local.hour)}:${two(local.minute)}";
  }

  Widget _buildCommentTile(ThemeData theme, MediaComment comment) {
    final isCommentAuthor = comment.userId == widget.currentUserId;
    final isWorkOwner =
        widget.currentUserId != null &&
        widget.mediaItemOwnerId != null &&
        widget.mediaItemOwnerId == widget.currentUserId;
    final canEdit = isCommentAuthor || isWorkOwner || widget.isAdminUser;
    final canDelete = isCommentAuthor || isWorkOwner || widget.isAdminUser;
    final canReport = _canComment && !isCommentAuthor;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.authorDisplayName,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          _formatCommentDate(comment.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canEdit || canDelete || canReport)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == "edit") {
                          unawaited(_edit(comment));
                        } else if (value == "delete") {
                          unawaited(_delete(comment));
                        } else if (value == "report") {
                          unawaited(_report(comment));
                        }
                      },
                      itemBuilder: (context) {
                        return [
                          if (canEdit)
                            const PopupMenuItem(
                              value: "edit",
                              child: Text("Редактировать"),
                            ),
                          if (canDelete)
                            const PopupMenuItem(
                              value: "delete",
                              child: Text("Удалить"),
                            ),
                          if (canReport)
                            const PopupMenuItem(
                              value: "report",
                              child: Text("Пожаловаться"),
                            ),
                        ];
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(comment.text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposeForm(ThemeData theme) {
    if (_canComment) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: "Напишите комментарий",
              border: OutlineInputBorder(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon:
                  _saving
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.send),
              label: const Text("Отправить"),
            ),
          ),
        ],
      );
    }
    return Text(
      widget.currentUserId == null
          ? "Войдите, чтобы оставить комментарий."
          : "Комментарии к демо-произведениям недоступны.",
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildCommentsBody({
    required ThemeData theme,
    required List<MediaComment> comments,
    Widget? trailing,
  }) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Text(_error!, style: TextStyle(color: theme.colorScheme.error));
    }
    if (_comments.isEmpty) {
      return Text(
        "Комментариев пока нет.",
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...comments.map((comment) => _buildCommentTile(theme, comment)),
        if (trailing != null) ...[const SizedBox(height: 8), trailing],
      ],
    );
  }
}

class _MediaCommentsSection extends _MediaCommentsWidget {
  const _MediaCommentsSection({
    super.key,
    required super.mediaItemId,
    required super.mediaItemOwnerId,
    required super.currentUserId,
    required super.isAdminUser,
    required super.onLoadComments,
    required super.onCreateComment,
    required super.onUpdateComment,
    required super.onDeleteComment,
    required super.onReportComment,
  });

  @override
  State<_MediaCommentsSection> createState() => _MediaCommentsSectionState();
}

class _MediaCommentsSectionState extends _MediaCommentsState<_MediaCommentsSection> {
  @override
  void didUpdateWidget(covariant _MediaCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItemId != widget.mediaItemId) {
      _comments = const [];
      _controller.clear();
      unawaited(_load());
    }
  }

  Future<void> _openAllCommentsPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (context) => _MediaCommentsPage(
              mediaItemId: widget.mediaItemId,
              mediaItemOwnerId: widget.mediaItemOwnerId,
              currentUserId: widget.currentUserId,
              isAdminUser: widget.isAdminUser,
              onLoadComments: widget.onLoadComments,
              onCreateComment: widget.onCreateComment,
              onUpdateComment: widget.onUpdateComment,
              onDeleteComment: widget.onDeleteComment,
              onReportComment: widget.onReportComment,
            ),
      ),
    );
    if (mounted) {
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMoreComments = _comments.length > _MediaCommentsState.previewCount;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text("Комментарии", style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                Text(
                  "${_comments.length}",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: "Обновить",
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCommentsBody(
              theme: theme,
              comments: _previewComments,
              trailing:
                  hasMoreComments
                      ? OutlinedButton(
                        onPressed: _openAllCommentsPage,
                        child: const Text("Показать все комментарии"),
                      )
                      : null,
            ),
            const SizedBox(height: 16),
            _buildComposeForm(theme),
          ],
        ),
      ),
    );
  }
}

class _MediaCommentsPage extends _MediaCommentsWidget {
  const _MediaCommentsPage({
    required super.mediaItemId,
    required super.mediaItemOwnerId,
    required super.currentUserId,
    required super.isAdminUser,
    required super.onLoadComments,
    required super.onCreateComment,
    required super.onUpdateComment,
    required super.onDeleteComment,
    required super.onReportComment,
  });

  @override
  State<_MediaCommentsPage> createState() => _MediaCommentsPageState();
}

class _MediaCommentsPageState extends _MediaCommentsState<_MediaCommentsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Комментарии"),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  _buildCommentsBody(
                    theme: theme,
                    comments: _comments,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildComposeForm(theme),
            ),
          ],
        ),
      ),
    );
  }
}