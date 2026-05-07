import "package:flutter/material.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.initialQuery,
    required this.onSearch,
    required this.onOpenLibrary,
    super.key,
  });

  final String initialQuery;
  final ValueChanged<String> onSearch;
  final VoidCallback onOpenLibrary;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;

  static const _quickQueries = [
    "Космос",
    "Детектив",
    "Фантастика",
    "Классика",
    "Саморазвитие",
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        _controller.text != widget.initialQuery) {
      _controller.text = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    widget.onSearch(value.trim());
    widget.onOpenLibrary();
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
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: "Искать книги, авторов...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () => _submit(_controller.text),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Популярные запросы",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickQueries
                  .map(
                    (query) => ActionChip(
                      label: Text(query),
                      onPressed: () {
                        _controller.text = query;
                        _submit(query);
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
