import "package:flutter/material.dart";

/// Диалог ввода названия полки; контроллер живёт внутри [State] диалога.
Future<String?> showShelfNameDialog(
  BuildContext context, {
  String title = "Новая полка",
  String? initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _ShelfNameDialog(title: title, initialName: initialName),
  );
}

class _ShelfNameDialog extends StatefulWidget {
  const _ShelfNameDialog({required this.title, this.initialName});

  final String title;
  final String? initialName;

  @override
  State<_ShelfNameDialog> createState() => _ShelfNameDialogState();
}

class _ShelfNameDialogState extends State<_ShelfNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? "");
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: "Название",
          hintText: "Например: Хочу прочитать",
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Отмена"),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text("Сохранить"),
        ),
      ],
    );
  }
}
