import "dart:async";

import "package:flutter/material.dart";

import "../../../../app/app_state.dart";
import "../../../library/presentation/media_cover.dart";

/// Список книг, скачанных на устройство текущего пользователя.
class DownloadedBooksScreen extends StatefulWidget {
  const DownloadedBooksScreen({required this.state, super.key});

  final AppState state;

  @override
  State<DownloadedBooksScreen> createState() => _DownloadedBooksScreenState();
}

class _DownloadedBooksScreenState extends State<DownloadedBooksScreen> {
  List<DownloadedBookDeviceItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.state.listDownloadedBooksOnDevice();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = "Не удалось загрузить скачанные книги";
      });
    }
  }

  Future<void> _deleteItem(DownloadedBookDeviceItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text("Удалить файл с устройства?"),
            content: Text("Книга \"${item.title}\" будет удалена только локально."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text("Отмена"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text("Удалить"),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await widget.state.deleteDownloadedBookFromDevice(item.mediaItemId);
    await _load();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Книга удалена с устройства")),
    );
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text("Удалить все скачанные книги?"),
            content: const Text(
              "Все локальные файлы книг будут удалены с этого устройства.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text("Отмена"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text("Удалить всё"),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await widget.state.deleteAllDownloadedBooksFromDevice();
    await _load();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Все скачанные книги удалены")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Скачанные книги"),
        actions: [
          IconButton(
            tooltip: "Удалить всё с устройства",
            onPressed: _items.isEmpty || _loading ? null : _deleteAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(onRefresh: _load, child: _buildList()),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text("На устройстве нет скачанных книг")),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 64,
                child: MediaCoverImage(coverUrl: item.coverUrl),
              ),
            ),
            title: Text(item.title),
            subtitle: Text("${item.author} · ${item.filename}"),
            trailing: IconButton(
              tooltip: "Удалить с устройства",
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteItem(item),
            ),
          ),
        );
      },
    );
  }
}

