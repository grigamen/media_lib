import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.initialQuery,
    required this.selectedTypes,
    required this.selectedGenres,
    required this.availableGenres,
    required this.onApply,
    required this.onOpenLibrary,
    super.key,
  });

  final String initialQuery;
  final List<String> selectedTypes;
  final List<String> selectedGenres;
  final List<String> availableGenres;
  final Future<void> Function(String query, List<String> types, List<String> genres)
  onApply;
  final VoidCallback onOpenLibrary;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late List<String> _types;
  late List<String> _genres;

  static const _typeSpecs = <({String key, String label})>[
    (key: "book", label: "Книги"),
    (key: "audiobook", label: "Аудиокниги"),
    (key: "video", label: "Видео"),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _types = List<String>.from(widget.selectedTypes);
    _genres = List<String>.from(widget.selectedGenres);
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    await widget.onApply(_controller.text.trim(), _types, _genres);
    widget.onOpenLibrary();
  }

  bool _genreSelected(String genre) {
    final lower = genre.trim().toLowerCase();
    return _genres.any((g) => g.toLowerCase() == lower);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          children: [
            Text("Поиск", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 14),
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
            Text(
              "Вид произведения",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              "Не отмечено — все виды. Можно выбрать несколько.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 20),
            Text(
              "Жанры",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _genres.isEmpty
                  ? "Не выбрано — любые жанры. Выберите один или несколько."
                  : "Показываются произведения, где есть хотя бы один из выбранных жанров.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.availableGenres.isEmpty)
              Text(
                "Список жанров загрузится после запроса каталога.",
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
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
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _types = [];
                    _genres = [];
                  });
                },
                child: const Text("Сбросить виды и жанры"),
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
