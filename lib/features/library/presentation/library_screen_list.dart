part of 'library_screen.dart';

List<String> _genresAfterToggling(List<String> genres, String genre) {
  final g = genre.trim();
  if (g.isEmpty) {
    return genres;
  }
  final lower = g.toLowerCase();
  final has = genres.any((existing) => existing.toLowerCase() == lower);
  if (has) {
    return genres
        .where((existing) => existing.toLowerCase() != lower)
        .toList(growable: false);
  }
  return [...genres, g];
}

bool _genreChipSelected(List<String> selected, String genre) {
  final lower = genre.trim().toLowerCase();
  return selected.any((g) => g.toLowerCase() == lower);
}

class _LibraryControls extends StatelessWidget {
  const _LibraryControls({
    required this.searchController,
    required this.typeFilter,
    required this.selectedGenres,
    required this.availableGenres,
    required this.onApplyFilters,
    required this.onSearchPressed,
  });

  final TextEditingController searchController;
  final String? typeFilter;
  final List<String> selectedGenres;
  final List<String> availableGenres;
  final Future<void> Function(
    String searchQuery,
    String? typeFilter,
    List<String> selectedGenres,
  )
  onApplyFilters;
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
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          onSubmitted:
              (_) => onApplyFilters(
                searchController.text.trim(),
                typeFilter,
                selectedGenres,
              ),
          decoration: InputDecoration(
            hintText: "Поиск в библиотеке...",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed:
                  () => onApplyFilters(
                    searchController.text.trim(),
                    typeFilter,
                    selectedGenres,
                  ),
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
                onTap:
                    () => onApplyFilters(
                      searchController.text.trim(),
                      null,
                      selectedGenres,
                    ),
              ),
              _FilterChip(
                label: "Книги",
                selected: selectedType == "book",
                onTap:
                    () => onApplyFilters(
                      searchController.text.trim(),
                      "book",
                      selectedGenres,
                    ),
              ),
              _FilterChip(
                label: "Аудиокниги",
                selected: selectedType == "audiobook",
                onTap:
                    () => onApplyFilters(
                      searchController.text.trim(),
                      "audiobook",
                      selectedGenres,
                    ),
              ),
              _FilterChip(
                label: "Видео",
                selected: selectedType == "video",
                onTap:
                    () => onApplyFilters(
                      searchController.text.trim(),
                      "video",
                      selectedGenres,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text("Жанры", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          selectedGenres.isEmpty
              ? "Не выбрано — любые. Нажмите несколько или откройте расширенный поиск."
              : "Показываются произведения с любым из выбранных жанров.",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (availableGenres.isEmpty)
          Text(
            "Список жанров подгружается вместе с каталогом. Потяните вниз для обновления.",
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final genre in availableGenres)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(genre),
                      selected: _genreChipSelected(selectedGenres, genre),
                      onSelected: (_) {
                        final next = _genresAfterToggling(selectedGenres, genre);
                        unawaited(
                          onApplyFilters(
                            searchController.text.trim(),
                            typeFilter,
                            next,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onSearchPressed,
            icon: const Icon(Icons.tune, size: 20),
            label: const Text("Расширенный поиск и виды"),
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
