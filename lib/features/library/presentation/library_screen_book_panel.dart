part of 'library_screen.dart';

class _BookContentPanel extends StatefulWidget {
  const _BookContentPanel({
    required this.item,
    required this.onLoadBookContent,
  });

  final MediaListItem item;
  final Future<String> Function(MediaListItem item) onLoadBookContent;

  @override
  State<_BookContentPanel> createState() => _BookContentPanelState();
}

class _BookContentPanelState extends State<_BookContentPanel> {
  late Future<String> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = widget.onLoadBookContent(widget.item);
  }

  @override
  void didUpdateWidget(covariant _BookContentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.mediaFileId != widget.item.mediaFileId) {
      _contentFuture = widget.onLoadBookContent(widget.item);
    }
  }

  void _reload() {
    setState(() {
      _contentFuture = widget.onLoadBookContent(widget.item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Текст книги"),
              SizedBox(height: 8),
              LinearProgressIndicator(),
            ],
          );
        }
        if (snapshot.hasError) {
          final message = snapshot.error?.toString() ?? "Неизвестная ошибка";
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Текст книги"),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text("Повторить"),
              ),
            ],
          );
        }

        final content = snapshot.data ?? "";
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Текст книги"),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 360),
                padding: const EdgeInsets.all(12),
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withAlpha(70),
                child: SingleChildScrollView(
                  child: SelectableText(
                    content,
                    style: const TextStyle(height: 1.35),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
