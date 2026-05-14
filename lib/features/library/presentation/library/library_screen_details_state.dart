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
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    height: 160,
                                    width: 110,
                                    child:
                                        activeItem.coverUrl?.isNotEmpty == true
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
                                      if (activeGenres.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: activeGenres
                                              .map(
                                                (genre) =>
                                                    Chip(label: Text(genre)),
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
                                            onLoadBookContent:
                                                widget.onLoadBookContent,
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
                                                widget.onBeginPlaybackSession,
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
}