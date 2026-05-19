part of 'library_screen.dart';

// То, что рисует главный список библиотеки: склеивает элементы в «произведения», обновление списка, карточки.

/// Всё состояние экрана [LibraryScreen]: поле поиска (для вида), сетка и переход в большую карточку.
class _LibraryScreenState extends State<LibraryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  /// Из длинного списка с сервера делает группы: одно название и автор — одна строка в сетке, внутри может быть несколько форматов.
  List<_WorkGroup> _buildWorkGroups(List<MediaListItem> items) {
    final groups = <String, List<MediaListItem>>{};
    for (final item in items) {
      final key =
          "${item.title.trim().toLowerCase()}::${(item.author ?? "").trim().toLowerCase()}";
      groups.putIfAbsent(key, () => <MediaListItem>[]).add(item);
    }
    final result = groups.values
        .map((groupItems) => _WorkGroup(groupItems: groupItems))
        .toList(growable: true);
    _sortWorkGroups(
      result,
      field: widget.librarySortField,
      descending: widget.librarySortDescending,
    );
    return result;
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Выезжающая снизу панель: показать «с чем на сервере связана эта запись» (для разработки и ясности).
  Future<void> _showLinksDialog(MediaListItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return FutureBuilder<List<MediaLinkItem>>(
          future: widget.onLoadLinks(item.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text("Не удалось загрузить связи")),
              );
            }
            final links = snapshot.data ?? const <MediaLinkItem>[];
            if (links.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text("Связей пока нет")),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final link = links[index];
                return ListTile(
                  leading: const Icon(Icons.link),
                  title: Text("Тип связи: ${link.relationType}"),
                  subtitle: Text(
                    "source: ${link.sourceMediaId}\ntarget: ${link.targetMediaId}",
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemCount: links.length,
            );
          },
        );
      },
    );
  }

  /// Пока грузится — крутилка, если ошибка — текст, если пусто — подсказка, иначе сетка карточек и обновление потягиванием.
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: Builder(
          builder: (context) {
            if (widget.isLoading && widget.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (widget.errorMessage != null && widget.items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                children: [
                  if (!widget.hideLibraryControls)
                    _LibraryControls(
                      searchController: _searchController,
                      searchQuery: widget.searchQuery,
                      selectedTypes: widget.selectedTypes,
                      selectedGenres: widget.selectedGenres,
                      librarySortField: widget.librarySortField,
                      librarySortDescending: widget.librarySortDescending,
                      onSetLibrarySortField: widget.onSetLibrarySortField,
                      onToggleLibrarySortDirection:
                          widget.onToggleLibrarySortDirection,
                      onSetLibraryFilters: widget.onSetLibraryFilters,
                      onSearchFieldTap: widget.onOpenSearchTab,
                    ),
                  const SizedBox(height: 64),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        widget.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            if (widget.items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                children: [
                  if (!widget.hideLibraryControls) ...[
                    _LibraryControls(
                      searchController: _searchController,
                      searchQuery: widget.searchQuery,
                      selectedTypes: widget.selectedTypes,
                      selectedGenres: widget.selectedGenres,
                      librarySortField: widget.librarySortField,
                      librarySortDescending: widget.librarySortDescending,
                      onSetLibrarySortField: widget.onSetLibrarySortField,
                      onToggleLibrarySortDirection:
                          widget.onToggleLibrarySortDirection,
                      onSetLibraryFilters: widget.onSetLibraryFilters,
                      onSearchFieldTap: widget.onOpenSearchTab,
                    ),
                  ],
                  const SizedBox(height: 64),
                  Center(
                    child: Text(
                      widget.emptyLibraryMessage ??
                          (widget.usingDemoItems
                              ? "Тестовые произведения не найдены по текущему фильтру"
                              : "Библиотека пока пустая"),
                    ),
                  ),
                ],
              );
            }
            final groups = _buildWorkGroups(widget.items);
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
              children: [
                if (!widget.hideLibraryControls)
                  _LibraryControls(
                    searchController: _searchController,
                    searchQuery: widget.searchQuery,
                    selectedTypes: widget.selectedTypes,
                    selectedGenres: widget.selectedGenres,
                    librarySortField: widget.librarySortField,
                    librarySortDescending: widget.librarySortDescending,
                    onSetLibrarySortField: widget.onSetLibrarySortField,
                    onToggleLibrarySortDirection:
                        widget.onToggleLibrarySortDirection,
                    onSetLibraryFilters: widget.onSetLibraryFilters,
                    onSearchFieldTap: widget.onOpenSearchTab,
                  ),
                if (widget.usingDemoItems) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Показаны тестовые произведения (backend вернул пустую библиотеку).",
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _LibraryItemCard(
                      group: group,
                      currentUserId: widget.currentUserId,
                      averageRating: _averageRatingForWorkGroup(
                        group.groupItems,
                      ),
                      onTap: () {
                        openMediaItemDetailsPage(
                          context: context,
                          currentUserId: widget.currentUserId,
                          groupItems: group.groupItems,
                          initialMediaItemId: resolveInitialMediaItemIdForGroup(
                            groupItems: group.groupItems,
                            selectedTypes: widget.selectedTypes,
                          ),
                          availableGenres: widget.availableGenres,
                          onLoadLinks: widget.onLoadLinks,
                          onLoadItemById: widget.onLoadItemById,
                          onUpdateItem: widget.onUpdateItem,
                          onAddFormatToWork: widget.onAddFormatToWork,
                          onBeginPlaybackSession: widget.onBeginPlaybackSession,
                          onPlaybackProgressChanged:
                              widget.onPlaybackProgressChanged,
                          onPausePlaybackSession: widget.onPausePlaybackSession,
                          onCompletePlaybackSession:
                              widget.onCompletePlaybackSession,
                          onFlushPlaybackSession: widget.onFlushPlaybackSession,
                          onEndPlaybackSession: widget.onEndPlaybackSession,
                          playbackSpeed: widget.playbackSpeed,
                          onSetPlaybackSpeed: widget.onSetPlaybackSpeed,
                          pendingPlaybackSync: widget.pendingPlaybackSync,
                          onFetchPlaybackStreamUrl:
                              widget.onFetchPlaybackStreamUrl,
                          playbackError: widget.playbackError,
                          onLoadBookContent: widget.onLoadBookContent,
                          onRecordMediaItemView: widget.onRecordMediaItemView,
                          onMarkItemViewed: widget.onMarkItemViewed,
                          onFetchMediaFiles: widget.onFetchMediaFiles,
                          onBindMainMediaFile: widget.onBindMainMediaFile,
                          onUploadAndBindMainMediaFile:
                              widget.onUploadAndBindMainMediaFile,
                          onFetchMediaProgress: widget.onFetchMediaProgress,
                          onSetMediaItemUserRating:
                              widget.onSetMediaItemUserRating,
                          onClearMediaItemUserRating:
                              widget.onClearMediaItemUserRating,
                          onFetchWorkUserRating: widget.onFetchWorkUserRating,
                          onSetWorkUserRating: ({
                            required List<String> mediaItemIds,
                            required int stars,
                          }) => widget.onSetWorkUserRating(
                            mediaItemIds: mediaItemIds,
                            stars: stars,
                          ),
                          onClearWorkUserRating: widget.onClearWorkUserRating,
                          onAddToShelf: widget.onAddToShelf,
                          onHasBookOfflineCopy: widget.onHasBookOfflineCopy,
                          onDownloadBookForOffline:
                              widget.onDownloadBookForOffline,
                          onSaveAuthorBookLocalFile:
                              widget.onSaveAuthorBookLocalFile,
                        );
                      },
                      onOpenLinks: () => _showLinksDialog(group.primaryItem),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
