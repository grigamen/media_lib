import "dart:async";

import "package:flutter/material.dart";

import "../../library/data/library_repository.dart";
import "../../library/presentation/media_cover.dart";
import "../../shelves/data/shelf_models.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.recentlyViewedItems,
    required this.catalogItems,
    required this.shelves,
    required this.isShelvesLoading,
    required this.shelvesError,
    required this.onOpenItem,
    required this.onOpenShelf,
    required this.onOpenAllShelves,
    required this.onRefreshShelves,
    super.key,
  });

  final List<MediaListItem> recentlyViewedItems;
  final List<MediaListItem> catalogItems;
  final List<UserShelfSummary> shelves;
  final bool isShelvesLoading;
  final String? shelvesError;
  final Future<void> Function(MediaListItem item) onOpenItem;
  final void Function(UserShelfSummary shelf) onOpenShelf;
  final VoidCallback onOpenAllShelves;
  final Future<void> Function() onRefreshShelves;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.shelves.isEmpty && !widget.isShelvesLoading) {
      unawaited(widget.onRefreshShelves());
    }
  }

  @override
  Widget build(BuildContext context) {
    String authorOrFallback(MediaListItem? item) {
      if (item == null) {
        return "Без автора";
      }
      final normalized = item.author?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
      return "Без автора";
    }

    final latestItem =
        widget.recentlyViewedItems.isNotEmpty
            ? widget.recentlyViewedItems.first
            : null;
    final previouslyViewed =
        widget.recentlyViewedItems.length > 1
            ? widget.recentlyViewedItems.skip(1).toList(growable: false)
            : <MediaListItem>[];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.onRefreshShelves,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              Text(
                "Главная",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Мои полки",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onOpenAllShelves,
                    child: const Text("Все полки"),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _HomeShelvesSection(
                shelves: widget.shelves,
                catalogItems: widget.catalogItems,
                isLoading: widget.isShelvesLoading,
                error: widget.shelvesError,
                onOpenShelf: widget.onOpenShelf,
                onOpenAllShelves: widget.onOpenAllShelves,
                onRetry: widget.onRefreshShelves,
              ),
              const SizedBox(height: 18),
              Text(
                "Последнее",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            _ContinueCard(
              item: latestItem,
              displayAuthor: authorOrFallback(latestItem),
              onOpenItem: widget.onOpenItem,
            ),
            const SizedBox(height: 18),
            Text(
              "Ранее просмотренные",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            if (previouslyViewed.isEmpty)
              Text(
                "Пока нет просмотренных произведений",
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...previouslyViewed.map(
                (item) => _RecommendationTile(
                  item: item,
                  displayAuthor: authorOrFallback(item),
                  onOpenItem: widget.onOpenItem,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeShelvesSection extends StatelessWidget {
  const _HomeShelvesSection({
    required this.shelves,
    required this.catalogItems,
    required this.isLoading,
    required this.error,
    required this.onOpenShelf,
    required this.onOpenAllShelves,
    required this.onRetry,
  });

  final List<UserShelfSummary> shelves;
  final List<MediaListItem> catalogItems;
  final bool isLoading;
  final String? error;
  final void Function(UserShelfSummary shelf) onOpenShelf;
  final VoidCallback onOpenAllShelves;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isLoading && shelves.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null && shelves.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            error!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          TextButton(
            onPressed: () => onRetry(),
            child: const Text("Повторить"),
          ),
        ],
      );
    }
    if (shelves.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Соберите произведения в свои подборки",
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                "Полки видите только вы. Добавляйте книги и фильмы из карточки "
                "кнопкой «На полку».",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: onOpenAllShelves,
                child: const Text("Создать полку"),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shelves.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final shelf = shelves[index];
          return _HomeShelfCard(
            shelf: shelf,
            catalogItems: catalogItems,
            onTap: () => onOpenShelf(shelf),
          );
        },
      ),
    );
  }
}

class _HomeShelfCard extends StatelessWidget {
  const _HomeShelfCard({
    required this.shelf,
    required this.catalogItems,
    required this.onTap,
  });

  final UserShelfSummary shelf;
  final List<MediaListItem> catalogItems;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 168,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 108,
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: MediaCoverImage(
                    coverUrl: shelfCoverUrlForShelf(shelf, catalogItems),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shelf.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          "${shelf.itemCount} на полке",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.item,
    required this.displayAuthor,
    required this.onOpenItem,
  });

  final MediaListItem? item;
  final String displayAuthor;
  final Future<void> Function(MediaListItem item) onOpenItem;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: item == null ? null : () => onOpenItem(item!),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 66,
              height: 92,
              child: MediaCoverImage(coverUrl: item?.coverUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item?.title ?? "Ничего не открыто",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(displayAuthor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.item,
    required this.displayAuthor,
    required this.onOpenItem,
  });

  final MediaListItem item;
  final String displayAuthor;
  final Future<void> Function(MediaListItem item) onOpenItem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onOpenItem(item),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 36,
                height: 52,
                child: MediaCoverImage(coverUrl: item.coverUrl),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    displayAuthor,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
