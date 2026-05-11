part of 'library_screen.dart';

class _LibraryControls extends StatelessWidget {
  const _LibraryControls({
    required this.searchController,
    required this.typeFilter,
    required this.onApplyFilters,
    required this.onAddPressed,
    required this.onSearchPressed,
  });

  final TextEditingController searchController;
  final String? typeFilter;
  final Future<void> Function(String searchQuery, String? typeFilter)
  onApplyFilters;
  final Future<void> Function() onAddPressed;
  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    final selectedType = typeFilter ?? "all";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "Библиотека",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              onPressed: onSearchPressed,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          onSubmitted:
              (_) => onApplyFilters(searchController.text.trim(), typeFilter),
          decoration: InputDecoration(
            hintText: "Поиск в библиотеке...",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed:
                  () =>
                      onApplyFilters(searchController.text.trim(), typeFilter),
              icon: const Icon(Icons.filter_alt_outlined),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: "Все",
                selected: selectedType == "all",
                onTap: () => onApplyFilters(searchController.text.trim(), null),
              ),
              _FilterChip(
                label: "Книги",
                selected: selectedType == "book",
                onTap:
                    () => onApplyFilters(searchController.text.trim(), "book"),
              ),
              _FilterChip(
                label: "Аудиокниги",
                selected: selectedType == "audiobook",
                onTap:
                    () => onApplyFilters(
                      searchController.text.trim(),
                      "audiobook",
                    ),
              ),
              _FilterChip(
                label: "Видео",
                selected: selectedType == "video",
                onTap:
                    () => onApplyFilters(searchController.text.trim(), "video"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _LibraryItemCard extends StatelessWidget {
  const _LibraryItemCard({
    required this.group,
    required this.onTap,
    required this.onOpenLinks,
    this.currentUserId,
  });

  final _WorkGroup group;
  final VoidCallback onTap;
  final VoidCallback onOpenLinks;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final modLabel = group.ownerModerationLabel(currentUserId);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child:
                          group.primaryItem.coverUrl?.isNotEmpty == true
                              ? Image.network(
                                group.primaryItem.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => const SizedBox.shrink(),
                              )
                              : const SizedBox.shrink(),
                    ),
                  ),
                  if (modLabel != null)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          modLabel,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GestureDetector(
                      onTap: onOpenLinks,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).scaffoldBackgroundColor.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: group.types
                              .map(
                                (type) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Icon(_iconForType(type), size: 14),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            group.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            group.displayAuthor.isNotEmpty ? group.displayAuthor : "Без автора",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    if (type == "audiobook") {
      return Icons.headphones;
    }
    if (type == "video") {
      return Icons.videocam_outlined;
    }
    return Icons.menu_book_outlined;
  }
}
