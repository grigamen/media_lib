import "dart:async";

import "package:flutter/material.dart";

import "../../../app/app_state.dart";
import "../../../app/media_lib_shell.dart";
import "../../library/data/library_models.dart";
import "../data/shelf_models.dart";
import "shelf_name_dialog.dart";

/// Содержимое одной полки.
class ShelfDetailScreen extends StatefulWidget {
  const ShelfDetailScreen({
    required this.state,
    required this.shelfId,
    required this.shelfName,
    super.key,
  });

  final AppState state;
  final String shelfId;
  final String shelfName;

  @override
  State<ShelfDetailScreen> createState() => _ShelfDetailScreenState();
}

class _ShelfDetailScreenState extends State<ShelfDetailScreen> {
  UserShelfDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ShelfDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shelfId != widget.shelfId) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.state.fetchShelfDetail(widget.shelfId);
      if (!mounted) {
        return;
      }
      if (detail == null) {
        setState(() {
          _loading = false;
          _error = "Не удалось загрузить полку";
        });
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = "Не удалось загрузить полку";
      });
    }
  }

  Future<void> _renameShelf() async {
    final name = await showShelfNameDialog(
      context,
      title: "Переименовать полку",
      initialName: _detail?.name ?? widget.shelfName,
    );
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    await widget.state.renameShelf(shelfId: widget.shelfId, name: name);
    if (mounted) {
      await _load();
    }
  }

  Future<void> _deleteShelf() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Удалить полку?"),
            content: const Text("Произведения из каталога не удалятся."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text("Отмена"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text("Удалить"),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await widget.state.deleteShelf(widget.shelfId);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _removeItem(MediaListItem item) async {
    await widget.state.removeMediaItemFromShelf(
      shelfId: widget.shelfId,
      mediaItemId: item.id,
    );
    await _load();
  }

  String _typeLabel(String type) {
    switch (type) {
      case "book":
        return "Книга";
      case "audiobook":
        return "Аудиокнига";
      case "video":
        return "Видео";
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _detail?.name ?? widget.shelfName;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: "Переименовать",
            onPressed: _renameShelf,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: "Удалить полку",
            onPressed: _deleteShelf,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                onRefresh: _load,
                child: _buildList(_detail!.items),
              ),
    );
  }

  Widget _buildList(List<MediaListItem> items) {
    if (items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "На полке пока пусто. Добавляйте произведения из карточки в библиотеке.",
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            leading:
                item.coverUrl?.isNotEmpty == true
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        item.coverUrl!,
                        width: 48,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.book),
                      ),
                    )
                    : const Icon(Icons.book_outlined),
            title: Text(item.title),
            subtitle: Text(
              "${item.author?.isNotEmpty == true ? item.author! : "Без автора"} · "
              "${_typeLabel(item.type)}",
            ),
            onTap: () {
              openWorkGroupItemDetails(
                context,
                widget.state,
                mediaItemsInWorkGroup(widget.state, item),
              );
            },
            trailing: IconButton(
              tooltip: "Убрать с полки",
              icon: const Icon(Icons.bookmark_remove_outlined),
              onPressed: () => _removeItem(item),
            ),
          ),
        );
      },
    );
  }
}
