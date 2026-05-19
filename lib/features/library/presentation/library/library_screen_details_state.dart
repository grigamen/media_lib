part of 'library_screen.dart';

// Сборка большого экрана: вкладки по форматам, текст, кнопки владельца, чтение книги или плеер.

/// Рисует вкладки, описание и панели действий, опираясь на набор общих фрагментов кода (миксины).
class _MediaItemDetailsPageState extends State<_MediaItemDetailsPage>
    with _MediaItemDetailsStateFields,
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
    _loadLinkedVariants();
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
            child: DefaultTabController(
              length: _variants.length,
              child: Builder(
                builder: (context) {
                  final tabController = DefaultTabController.of(context);
                  return AnimatedBuilder(
                    animation: tabController,
                    builder: (context, child) {
                      final selectedIndex = tabController.index.clamp(
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
                                        child:
                                            activeItem.coverUrl?.isNotEmpty ==
                                                    true
                                                ? Image.network(
                                                  activeItem.coverUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, __, ___) => Container(
                                                        color: Colors.black12,
                                                        child: const Center(
                                                          child: Icon(
                                                            Icons
                                                                .broken_image_outlined,
                                                          ),
                                                        ),
                                                      ),
                                                )
                                                : Container(
                                                  color: Colors.black12,
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons
                                                          .image_not_supported_outlined,
                                                    ),
                                                  ),
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
                                      Text(activeAuthor),
                                      if (_averageRatingForWorkGroup(
                                            _variants,
                                          )
                                          case final summary?) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              summary.average.toStringAsFixed(
                                                1,
                                              ),
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.star,
                                              size: 20,
                                              color: Colors.amber.shade700,
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.visibility_outlined,
                                            size: 18,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatViewsCount(
                                              _totalViewsForWorkGroup(
                                                _variants,
                                              ),
                                            ),
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                          ),
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
                                if (widget.currentUserId != null) ...[
                                  const SizedBox(height: 8),
                                  _WorkUserRatingBar(
                                    key: ValueKey(
                                      _rateableVariantIds.join("|"),
                                    ),
                                    onLoadStars:
                                        () => widget.onFetchWorkUserRating(
                                          _rateableVariantIds,
                                        ),
                                    onSetStars:
                                        (stars) => widget.onSetWorkUserRating(
                                          mediaItemIds: _rateableVariantIds,
                                          stars: stars,
                                        ),
                                    onClearStars:
                                        () => widget.onClearWorkUserRating(
                                          _rateableVariantIds,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          TabBar(
                            isScrollable: true,
                            tabs: _variants
                                .map(
                                  (item) => Tab(text: _labelForType(item.type)),
                                )
                                .toList(growable: false),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: _variants
                                  .map(
                                    (item) => ListView(
                                      key: ValueKey<String>(item.id),
                                      padding: const EdgeInsets.all(16),
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.visibility_outlined,
                                              size: 18,
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatViewsCount(
                                                item.viewsCount,
                                              ),
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
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
                                                Text(
                                                  "Описание",
                                                  style:
                                                      Theme.of(
                                                        context,
                                                      ).textTheme.labelLarge,
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
                                            onOpenReader:
                                                () => _openBookReader(item),
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
                                      ],
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
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
}

/// Звёздная оценка произведения (1–5) для всех форматов работы.
class _WorkUserRatingBar extends StatefulWidget {
  const _WorkUserRatingBar({
    super.key,
    required this.onLoadStars,
    required this.onSetStars,
    required this.onClearStars,
  });

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
                                      ? Colors.amber.shade700
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