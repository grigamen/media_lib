import "package:flutter/material.dart";

import "../../library/data/library_repository.dart";

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.recentlyViewedItems,
    required this.onOpenItem,
    super.key,
  });

  final List<MediaListItem> recentlyViewedItems;
  final Future<void> Function(MediaListItem item) onOpenItem;

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
        recentlyViewedItems.isNotEmpty ? recentlyViewedItems.first : null;
    final previouslyViewed =
        recentlyViewedItems.length > 1
            ? recentlyViewedItems.skip(1).toList(growable: false)
            : <MediaListItem>[];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            Text("Главная", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 18),
            Text(
              "Последнее",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            _ContinueCard(
              item: latestItem,
              displayAuthor: authorOrFallback(latestItem),
              onOpenItem: onOpenItem,
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
                  onOpenItem: onOpenItem,
                ),
              ),
          ],
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
              child:
                  item?.coverUrl?.isNotEmpty == true
                      ? Image.network(
                        item!.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) =>
                                Container(color: const Color(0xFF4A4757)),
                      )
                      : Container(color: const Color(0xFF4A4757)),
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
                child:
                    item.coverUrl?.isNotEmpty == true
                        ? Image.network(
                          item.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) =>
                                  Container(color: const Color(0xFF4A4757)),
                        )
                        : Container(color: const Color(0xFF4A4757)),
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
