part of 'library_screen.dart';

// Текст и кнопка «Читать»: по нажатию открывается отдельный экран читалки с сохранением места в тексте.

/// Небольшой блок под книгой: чтение, офлайн-скачивание и (для автора) свой файл на устройстве.
class _BookReadLaunchPanel extends StatefulWidget {
  const _BookReadLaunchPanel({
    required this.item,
    required this.isOwner,
    required this.canUseOffline,
    required this.onOpenReader,
    this.onDownloadForOffline,
    this.onPickLocalFile,
    this.checkHasOfflineCopy,
  });

  final MediaListItem item;
  final bool isOwner;
  final bool canUseOffline;
  final VoidCallback onOpenReader;
  final Future<bool> Function()? onDownloadForOffline;
  final Future<void> Function()? onPickLocalFile;
  final Future<bool> Function()? checkHasOfflineCopy;

  @override
  State<_BookReadLaunchPanel> createState() => _BookReadLaunchPanelState();
}

class _BookReadLaunchPanelState extends State<_BookReadLaunchPanel> {
  bool _hasOfflineCopy = false;
  bool _checkedOffline = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshOfflineFlag());
  }

  @override
  void didUpdateWidget(covariant _BookReadLaunchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.checkHasOfflineCopy != widget.checkHasOfflineCopy) {
      unawaited(_refreshOfflineFlag());
    }
  }

  Future<void> _refreshOfflineFlag() async {
    final checker = widget.checkHasOfflineCopy;
    if (checker == null) {
      if (mounted) {
        setState(() {
          _hasOfflineCopy = false;
          _checkedOffline = true;
        });
      }
      return;
    }
    final hasOffline = await checker();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasOfflineCopy = hasOffline;
      _checkedOffline = true;
    });
  }

  Future<void> _downloadForOffline() async {
    final download = widget.onDownloadForOffline;
    if (download == null || _downloading) {
      return;
    }
    setState(() => _downloading = true);
    try {
      final ok = await download();
      if (!mounted) {
        return;
      }
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Книга сохранена на устройстве для чтения без сети"),
          ),
        );
        await _refreshOfflineFlag();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Не удалось скачать книгу")),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  Future<void> _pickLocalFile() async {
    final pick = widget.onPickLocalFile;
    if (pick == null) {
      return;
    }
    await pick();
    await _refreshOfflineFlag();
  }

  String _descriptionText() {
    if (_hasOfflineCopy) {
      return "Книга на устройстве — можно читать без интернета.";
    }
    if (widget.isOwner) {
      return "Скачайте книгу на устройство или укажите свой файл — чтение без загрузки с сервера при каждом открытии.";
    }
    return "Скачайте текст книги на устройство, чтобы читать без интернета.";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Чтение",
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _descriptionText(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: widget.onOpenReader,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text("Читать"),
        ),
        if (widget.canUseOffline && widget.onDownloadForOffline != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _downloading || _hasOfflineCopy ? null : _downloadForOffline,
            icon:
                _downloading
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Icon(
                      _hasOfflineCopy
                          ? Icons.offline_pin
                          : Icons.download_outlined,
                    ),
            label: Text(
              _hasOfflineCopy
                  ? "Скачано на устройство"
                  : "Скачать на устройство",
            ),
          ),
        ],
        if (widget.isOwner && widget.onPickLocalFile != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickLocalFile,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text("Указать свой файл на устройстве"),
          ),
        ],
        if (widget.canUseOffline &&
            _checkedOffline &&
            !_hasOfflineCopy &&
            !widget.item.id.startsWith("demo-")) ...[
          const SizedBox(height: 6),
          Text(
            "Поддерживаются текстовые книги (txt, md, docx). После скачивания «Читать» работает офлайн.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
