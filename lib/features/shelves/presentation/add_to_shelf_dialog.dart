import "dart:async";

import "package:flutter/material.dart";

import "../../../app/app_state.dart";
import "../../../core/network/api_client.dart";
import "../data/shelf_models.dart";
import "shelf_name_dialog.dart";

/// Выбор полки или создание новой; добавляет [mediaItemId] на выбранную полку.
Future<bool> showAddToShelfDialog({
  required BuildContext context,
  required AppState state,
  required String mediaItemId,
}) async {
  if (mediaItemId.startsWith("demo-")) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Для тестовых произведений полки недоступны"),
        ),
      );
    }
    return false;
  }

  final added = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _AddToShelfSheet(state: state, mediaItemId: mediaItemId);
    },
  );
  return added == true;
}

class _AddToShelfSheet extends StatefulWidget {
  const _AddToShelfSheet({required this.state, required this.mediaItemId});

  final AppState state;
  final String mediaItemId;

  @override
  State<_AddToShelfSheet> createState() => _AddToShelfSheetState();
}

class _AddToShelfSheetState extends State<_AddToShelfSheet> {
  List<UserShelfSummary> _shelves = const [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadShelves());
  }

  Future<void> _loadShelves() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await widget.state.fetchShelves();
    if (!mounted) {
      return;
    }
    setState(() {
      _shelves = List<UserShelfSummary>.from(widget.state.shelves);
      _loading = false;
      _error = widget.state.shelvesError;
    });
  }

  void _closeWithSuccess() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _createAndAdd() async {
    final name = await showShelfNameDialog(context);
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final shelf = await widget.state.createShelf(name);
      if (!mounted) {
        return;
      }
      if (shelf == null) {
        setState(() => _busy = false);
        return;
      }
      final added = await widget.state.addMediaItemToShelf(
        shelfId: shelf.id,
        mediaItemId: widget.mediaItemId,
      );
      if (!mounted) {
        return;
      }
      if (!added) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Произведение не появилось на полке. Проверьте backend.",
            ),
          ),
        );
        return;
      }
      _closeWithSuccess();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Не удалось создать полку: $e")));
    }
  }

  Future<void> _addToShelf(String shelfId) async {
    setState(() => _busy = true);
    try {
      final added = await widget.state.addMediaItemToShelf(
        shelfId: shelfId,
        mediaItemId: widget.mediaItemId,
      );
      if (!mounted) {
        return;
      }
      if (!added) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Произведение не появилось на полке. Обновите backend и миграции.",
            ),
          ),
        );
        return;
      }
      _closeWithSuccess();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Не удалось добавить на полку: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Добавить на полку",
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _createAndAdd,
              icon: const Icon(Icons.add),
              label: const Text("Создать полку и добавить"),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                children: [
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _busy ? null : _loadShelves,
                    child: const Text("Повторить"),
                  ),
                ],
              )
            else if (_shelves.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "У вас пока нет полок. Создайте первую кнопкой выше.",
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _shelves.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final shelf = _shelves[index];
                    return ListTile(
                      leading: const Icon(Icons.bookmarks_outlined),
                      title: Text(shelf.name),
                      subtitle: Text(
                        "${shelf.itemCount} ${_pluralWorks(shelf.itemCount)}",
                      ),
                      enabled: !_busy,
                      onTap: () => _addToShelf(shelf.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _pluralWorks(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) {
      return "произведений";
    }
    if (mod10 == 1) {
      return "произведение";
    }
    if (mod10 >= 2 && mod10 <= 4) {
      return "произведения";
    }
    return "произведений";
  }
}
