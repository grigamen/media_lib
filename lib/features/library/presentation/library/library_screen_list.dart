part of 'library_screen.dart';

// Заголовок «Библиотека», строка поиска (она только открывает отдельный экран) и чипы активных фильтров.

/// Внутренний код типа контента (как приходит с сервера) превращаем в короткую подпись для цветных чипов.
String _libraryMediaTypeLabel(String key) {
  switch (key) {
    case "book":
      return "Книги";
    case "audiobook":
      return "Аудиокниги";
    case "video":
      return "Видео";
    default:
      return key;
  }
}

/// Длинный поисковый запрос обрезаем с «…», чтобы чип на экране не раздувался на несколько строк.
String _truncateForChip(String value, int maxLen) {
  final t = value.trim();
  if (t.length <= maxLen) {
    return t;
  }
  return "${t.substring(0, maxLen)}…";
}

class _LibraryControls extends StatelessWidget {
  const _LibraryControls({
    required this.searchController,
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
    required this.onSearchFieldTap,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final List<String> selectedTypes;
  final List<String> selectedGenres;
  final LibraryRatingCriteria libraryRatingCriteria;
  final LibraryViewsCriteria libraryViewsCriteria;
  final LibrarySortField librarySortField;
  final bool librarySortDescending;
  final void Function(LibrarySortField field) onSetLibrarySortField;
  final VoidCallback onToggleLibrarySortDirection;
  final Future<void> Function(
    String searchQuery,
    List<String> selectedTypes,
    List<String> selectedGenres,
    LibraryRatingCriteria ratingCriteria,
    LibraryViewsCriteria viewsCriteria,
  )
  onSetLibraryFilters;
  final VoidCallback onSearchFieldTap;

  /// Верх экрана: название раздела, поле «Поиск» (по нажатию уходит на другой экран) и сброс фильтров по чипам.
  @override
  Widget build(BuildContext context) {
    final q = searchQuery.trim();
    final hasActiveFilters =
        q.isNotEmpty ||
        selectedTypes.isNotEmpty ||
        selectedGenres.isNotEmpty ||
        libraryRatingCriteria.isActive ||
        libraryViewsCriteria.isActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Библиотека",
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          readOnly: true,
          enableInteractiveSelection: false,
          onTap: onSearchFieldTap,
          decoration: const InputDecoration(
            hintText: "Поиск и фильтры…",
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownMenu<LibrarySortField>(
                initialSelection: librarySortField,
                label: const Text("Сортировка"),
                expandedInsets: EdgeInsets.zero,
                onSelected: (field) {
                  if (field != null) {
                    onSetLibrarySortField(field);
                  }
                },
                dropdownMenuEntries: [
                  for (final field in LibrarySortField.values)
                    DropdownMenuEntry(
                      value: field,
                      label: field.label,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip:
                  librarySortDescending
                      ? "По убыванию"
                      : "По возрастанию",
              onPressed: onToggleLibrarySortDirection,
              icon: Icon(
                librarySortDescending
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
              ),
            ),
          ],
        ),
        if (hasActiveFilters) ...[
          const SizedBox(height: 12),
          Text(
            "Активные фильтры",
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (q.isNotEmpty)
                InputChip(
                  label: Text(
                    "Запрос: «${_truncateForChip(q, 28)}»",
                  ),
                  onDeleted: () {
                    unawaited(
                      onSetLibraryFilters(
                        "",
                        selectedTypes,
                        selectedGenres,
                        libraryRatingCriteria,
                        libraryViewsCriteria,
                      ),
                    );
                  },
                ),
              for (final typeKey in selectedTypes)
                InputChip(
                  label: Text(_libraryMediaTypeLabel(typeKey)),
                  onDeleted: () {
                    final next = selectedTypes
                        .where((t) => t != typeKey)
                        .toList(growable: false);
                    unawaited(
                      onSetLibraryFilters(
                        q,
                        next,
                        selectedGenres,
                        libraryRatingCriteria,
                        libraryViewsCriteria,
                      ),
                    );
                  },
                ),
              for (final genre in selectedGenres)
                InputChip(
                  label: Text(genre),
                  onDeleted: () {
                    final lower = genre.toLowerCase();
                    final next = selectedGenres
                        .where((g) => g.toLowerCase() != lower)
                        .toList(growable: false);
                    unawaited(
                      onSetLibraryFilters(
                        q,
                        selectedTypes,
                        next,
                        libraryRatingCriteria,
                        libraryViewsCriteria,
                      ),
                    );
                  },
                ),
              if (libraryRatingCriteria.presenceChipLabel != null)
                InputChip(
                  label: Text(libraryRatingCriteria.presenceChipLabel!),
                  onDeleted: () {
                    unawaited(
                      onSetLibraryFilters(
                        q,
                        selectedTypes,
                        selectedGenres,
                        libraryRatingCriteria.copyWith(
                          presence: LibraryRatingPresence.any,
                        ),
                        libraryViewsCriteria,
                      ),
                    );
                  },
                ),
              if (libraryRatingCriteria.boundChipLabel != null)
                InputChip(
                  label: Text(libraryRatingCriteria.boundChipLabel!),
                  onDeleted: () {
                    unawaited(
                      onSetLibraryFilters(
                        q,
                        selectedTypes,
                        selectedGenres,
                        libraryRatingCriteria.copyWith(clearBound: true),
                        libraryViewsCriteria,
                      ),
                    );
                  },
                ),
              if (libraryViewsCriteria.presenceChipLabel != null)
                InputChip(
                  label: Text(libraryViewsCriteria.presenceChipLabel!),
                  onDeleted: () {
                    unawaited(
                      onSetLibraryFilters(
                        q,
                        selectedTypes,
                        selectedGenres,
                        libraryRatingCriteria,
                        libraryViewsCriteria.copyWith(
                          presence: LibraryViewsPresence.any,
                        ),
                      ),
                    );
                  },
                ),
              if (libraryViewsCriteria.boundChipLabel != null)
                InputChip(
                  label: Text(libraryViewsCriteria.boundChipLabel!),
                  onDeleted: () {
                    unawaited(
                      onSetLibraryFilters(
                        q,
                        selectedTypes,
                        selectedGenres,
                        libraryRatingCriteria,
                        libraryViewsCriteria.copyWith(clearBound: true),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LibraryItemCard extends StatelessWidget {
  const _LibraryItemCard({
    required this.group,
    required this.onTap,
    required this.onOpenLinks,
    this.currentUserId,
    this.averageRating,
  });

  final _WorkGroup group;
  final VoidCallback onTap;
  final VoidCallback onOpenLinks;
  final String? currentUserId;
  final _WorkAverageRating? averageRating;

  /// Одна ячейка сетки: обложка, при необходимости плашка модерации, иконки «есть книга/аудио/видео», открытие карточки.
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
                      child: _mediaCoverImage(
                        context,
                        coverUrl: group.primaryItem.coverUrl,
                      ),
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
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _libraryGridRatingLabel(context, averageRating),
              ),
              _libraryGridViewsLabel(context, group.groupItems),
            ],
          ),
        ],
      ),
    );
  }

  /// Какую маленькую картинку показать в углу: книга, наушники или камера.
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
