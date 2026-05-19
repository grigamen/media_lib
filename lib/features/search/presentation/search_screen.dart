import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "../../library/data/library_filters.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.initialQuery,
    required this.selectedTypes,
    required this.selectedGenres,
    required this.ratingCriteria,
    required this.viewsCriteria,
    required this.availableGenres,
    required this.onApply,
    required this.onOpenLibrary,
    super.key,
  });

  final String initialQuery;
  final List<String> selectedTypes;
  final List<String> selectedGenres;
  final LibraryRatingCriteria ratingCriteria;
  final LibraryViewsCriteria viewsCriteria;
  final List<String> availableGenres;
  final Future<void> Function(
    String query,
    List<String> types,
    List<String> genres,
    LibraryRatingCriteria ratingCriteria,
    LibraryViewsCriteria viewsCriteria,
  )
  onApply;
  final VoidCallback onOpenLibrary;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final TextEditingController _ratingBoundController;
  late final TextEditingController _viewsBoundController;
  late List<String> _types;
  late List<String> _genres;
  late LibraryRatingPresence _ratingPresence;
  late LibraryViewsPresence _viewsPresence;
  LibraryBoundCompare? _ratingBoundCompare;
  LibraryBoundCompare? _viewsBoundCompare;

  static const _typeSpecs = <({String key, String label})>[
    (key: "book", label: "Книги"),
    (key: "audiobook", label: "Аудиокниги"),
    (key: "video", label: "Видео"),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _ratingBoundController = TextEditingController(
      text: _formatRatingBound(widget.ratingCriteria.boundValue),
    );
    _viewsBoundController = TextEditingController(
      text: widget.viewsCriteria.boundValue?.toString() ?? "",
    );
    _types = List<String>.from(widget.selectedTypes);
    _genres = List<String>.from(widget.selectedGenres);
    _ratingPresence = widget.ratingCriteria.presence;
    _viewsPresence = widget.viewsCriteria.presence;
    _ratingBoundCompare = widget.ratingCriteria.boundCompare;
    _viewsBoundCompare = widget.viewsCriteria.boundCompare;
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        _controller.text != widget.initialQuery) {
      _controller.text = widget.initialQuery;
    }
    if (!listEquals(widget.selectedTypes, oldWidget.selectedTypes)) {
      _types = List<String>.from(widget.selectedTypes);
    }
    if (!listEquals(widget.selectedGenres, oldWidget.selectedGenres)) {
      _genres = List<String>.from(widget.selectedGenres);
    }
    if (widget.ratingCriteria != oldWidget.ratingCriteria) {
      _ratingPresence = widget.ratingCriteria.presence;
      _ratingBoundCompare = widget.ratingCriteria.boundCompare;
      final formatted = _formatRatingBound(widget.ratingCriteria.boundValue);
      if (_ratingBoundController.text != formatted) {
        _ratingBoundController.text = formatted;
      }
    }
    if (widget.viewsCriteria != oldWidget.viewsCriteria) {
      _viewsPresence = widget.viewsCriteria.presence;
      _viewsBoundCompare = widget.viewsCriteria.boundCompare;
      final formatted = widget.viewsCriteria.boundValue?.toString() ?? "";
      if (_viewsBoundController.text != formatted) {
        _viewsBoundController.text = formatted;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _ratingBoundController.dispose();
    _viewsBoundController.dispose();
    super.dispose();
  }

  static String _formatRatingBound(double? value) {
    if (value == null) {
      return "";
    }
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
  }

  void _toggleType(String key) {
    setState(() {
      if (_types.contains(key)) {
        _types = _types.where((t) => t != key).toList(growable: false);
      } else {
        _types = [..._types, key];
      }
    });
  }

  void _toggleGenre(String genre) {
    final g = genre.trim();
    if (g.isEmpty) {
      return;
    }
    setState(() {
      final lower = g.toLowerCase();
      final has =
          _genres.any((existing) => existing.toLowerCase() == lower);
      if (has) {
        _genres =
            _genres
                .where((existing) => existing.toLowerCase() != lower)
                .toList(growable: false);
      } else {
        _genres = [..._genres, g];
      }
    });
  }

  void _selectRatingPresence(LibraryRatingPresence next) {
    setState(() {
      _ratingPresence =
          _ratingPresence == next ? LibraryRatingPresence.any : next;
    });
  }

  void _selectViewsPresence(LibraryViewsPresence next) {
    setState(() {
      _viewsPresence = _viewsPresence == next ? LibraryViewsPresence.any : next;
    });
  }

  LibraryRatingCriteria _buildRatingCriteria() {
    final boundValue = parseRatingBoundInput(_ratingBoundController.text);
    final compare = boundValue != null ? _ratingBoundCompare : null;
    return LibraryRatingCriteria(
      presence: _ratingPresence,
      boundCompare: compare,
      boundValue: boundValue,
    );
  }

  LibraryViewsCriteria _buildViewsCriteria() {
    final boundValue = parseViewsBoundInput(_viewsBoundController.text);
    final compare = boundValue != null ? _viewsBoundCompare : null;
    return LibraryViewsCriteria(
      presence: _viewsPresence,
      boundCompare: compare,
      boundValue: boundValue,
    );
  }

  Future<void> _submit() async {
    await widget.onApply(
      _controller.text.trim(),
      _types,
      _genres,
      _buildRatingCriteria(),
      _buildViewsCriteria(),
    );
    widget.onOpenLibrary();
  }

  bool _genreSelected(String genre) {
    final lower = genre.trim().toLowerCase();
    return _genres.any((g) => g.toLowerCase() == lower);
  }

  Widget _section(BuildContext context, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _boundRow({
    required String valueHint,
    required TextEditingController valueController,
    required LibraryBoundCompare? compare,
    required ValueChanged<LibraryBoundCompare?> onCompareChanged,
    TextInputType keyboardType = TextInputType.number,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(labelForBoundCompare(LibraryBoundCompare.greater)),
                selected: compare == LibraryBoundCompare.greater,
                onSelected:
                    (_) => onCompareChanged(
                      compare == LibraryBoundCompare.greater
                          ? null
                          : LibraryBoundCompare.greater,
                    ),
              ),
              FilterChip(
                label: Text(labelForBoundCompare(LibraryBoundCompare.less)),
                selected: compare == LibraryBoundCompare.less,
                onSelected:
                    (_) => onCompareChanged(
                      compare == LibraryBoundCompare.less
                          ? null
                          : LibraryBoundCompare.less,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: TextField(
            controller: valueController,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: valueHint,
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          children: [
            TextField(
              controller: _controller,
              onSubmitted: (_) => unawaited(_submit()),
              decoration: InputDecoration(
                hintText: "Искать книги, авторов...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: "Применить фильтры и показать в библиотеке",
                  onPressed: () => unawaited(_submit()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _section(
              context,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final spec in _typeSpecs)
                    FilterChip(
                      label: Text(spec.label),
                      selected: _types.contains(spec.key),
                      onSelected: (_) => _toggleType(spec.key),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 20),
            _section(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text("С рейтингом"),
                        selected:
                            _ratingPresence == LibraryRatingPresence.withRating,
                        onSelected:
                            (_) => _selectRatingPresence(
                              LibraryRatingPresence.withRating,
                            ),
                      ),
                      FilterChip(
                        label: const Text("Без рейтинга"),
                        selected:
                            _ratingPresence ==
                            LibraryRatingPresence.withoutRating,
                        onSelected:
                            (_) => _selectRatingPresence(
                              LibraryRatingPresence.withoutRating,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _boundRow(
                    valueHint: "4",
                    valueController: _ratingBoundController,
                    compare: _ratingBoundCompare,
                    onCompareChanged: (value) {
                      setState(() => _ratingBoundCompare = value);
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 20),
            _section(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text("С просмотрами"),
                        selected:
                            _viewsPresence == LibraryViewsPresence.withViews,
                        onSelected:
                            (_) => _selectViewsPresence(
                              LibraryViewsPresence.withViews,
                            ),
                      ),
                      FilterChip(
                        label: const Text("Без просмотров"),
                        selected:
                            _viewsPresence == LibraryViewsPresence.withoutViews,
                        onSelected:
                            (_) => _selectViewsPresence(
                              LibraryViewsPresence.withoutViews,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _boundRow(
                    valueHint: "100",
                    valueController: _viewsBoundController,
                    compare: _viewsBoundCompare,
                    onCompareChanged: (value) {
                      setState(() => _viewsBoundCompare = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 20),
            if (widget.availableGenres.isEmpty)
              const SizedBox.shrink()
            else
              _section(
                context,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final genre in widget.availableGenres)
                      FilterChip(
                        label: Text(genre),
                        selected: _genreSelected(genre),
                        onSelected: (_) => _toggleGenre(genre),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _types = [];
                    _genres = [];
                    _ratingPresence = LibraryRatingPresence.any;
                    _viewsPresence = LibraryViewsPresence.any;
                    _ratingBoundCompare = null;
                    _viewsBoundCompare = null;
                    _ratingBoundController.clear();
                    _viewsBoundController.clear();
                  });
                },
                child: const Text("Сбросить фильтры"),
              ),
            ),
            FilledButton(
              onPressed: () => unawaited(_submit()),
              child: const Text("Показать в библиотеке"),
            ),
          ],
        ),
      ),
    );
  }
}
