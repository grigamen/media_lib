import "dart:async";

import "package:flutter/material.dart";

import "../../../app/app_state.dart";
import "shelf_detail_screen.dart";
import "shelf_name_dialog.dart";

/// Список личных полок пользователя.
class ShelvesScreen extends StatefulWidget {
  const ShelvesScreen({required this.state, super.key});

  final AppState state;

  @override
  State<ShelvesScreen> createState() => _ShelvesScreenState();
}

class _ShelvesScreenState extends State<ShelvesScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.state.fetchShelves());
  }

  Future<void> _createShelf() async {
    final name = await showShelfNameDialog(context);
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    await widget.state.createShelf(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Мои полки")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createShelf,
        icon: const Icon(Icons.add),
        label: const Text("Полка"),
      ),
      body: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          if (widget.state.isShelvesLoading && widget.state.shelves.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = widget.state.shelvesError;
          if (error != null && widget.state.shelves.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => widget.state.fetchShelves(),
                      child: const Text("Повторить"),
                    ),
                  ],
                ),
              ),
            );
          }
          final shelves = widget.state.shelves;
          if (shelves.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Создайте полку, чтобы собирать произведения в свои подборки. "
                  "Полки видите только вы.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: widget.state.fetchShelves,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: shelves.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final shelf = shelves[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.bookmarks_outlined),
                    title: Text(shelf.name),
                    subtitle: Text("${shelf.itemCount} на полке"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => ShelfDetailScreen(
                                state: widget.state,
                                shelfId: shelf.id,
                                shelfName: shelf.name,
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
