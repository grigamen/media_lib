part of 'library_screen.dart';

class _OwnerMainMediaFileCardState extends State<_OwnerMainMediaFileCard> {
  bool _busy = false;
  late Future<List<MediaFileSummary>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = widget.onFetchFiles(widget.item.id);
  }

  @override
  void didUpdateWidget(covariant _OwnerMainMediaFileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id) {
      _filesFuture = widget.onFetchFiles(widget.item.id);
    }
  }

  void _reloadFilesList() {
    if (!mounted) {
      return;
    }
    setState(() {
      _filesFuture = widget.onFetchFiles(widget.item.id);
    });
  }

  bool _isCompatibleContentType(String rawContentType) {
    final ct = rawContentType.toLowerCase().trim();
    if (widget.item.type == "audiobook") {
      return ct.startsWith("audio/");
    }
    if (widget.item.type == "video") {
      return ct.startsWith("video/");
    }
    if (widget.item.type == "book") {
      return ct == "text/plain" ||
          ct == "text/markdown" ||
          ct == "application/pdf" ||
          ct == "application/epub+zip" ||
          ct ==
              "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    }
    return false;
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    if (_busy) {
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: const [
        "mp3",
        "m4a",
        "aac",
        "wav",
        "ogg",
        "mp4",
        "webm",
        "mov",
        "mkv",
        "avi",
        "avl",
        "txt",
        "md",
        "pdf",
        "epub",
        "docx",
      ],
    );
    if (!context.mounted) {
      return;
    }
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.single;
    final name = file.name;
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось прочитать файл")),
      );
      return;
    }
    final mime = widget.inferContentTypeFromName(name);
    final resolvedMime = mime ?? widget.fallbackContentType(widget.item.type);
    if (!widget.isFileCompatibleWithType(
      filename: name,
      mimeType: resolvedMime,
      mediaType: widget.item.type,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Тип файла не подходит для ${_labelForType(widget.item.type).toLowerCase()}.",
          ),
        ),
      );
      return;
    }
    final payload = MediaUploadPayload.tryFromPlatformFile(
      file: file,
      contentType: resolvedMime,
    );
    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось прочитать файл")),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onUploadAndBind(
        mediaItemId: widget.item.id,
        uploadPayload: payload,
      );
      await widget.onVariantRefreshed();
      _reloadFilesList();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Файл загружен и привязан")));
    } on ApiException catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось загрузить файл")),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _bindExisting(String fileId, BuildContext context) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onBindFile(mediaItemId: widget.item.id, fileId: fileId);
      await widget.onVariantRefreshed();
      _reloadFilesList();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Выбран файл для воспроизведения")),
      );
    } on ApiException catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось привязать файл")),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final boundId = widget.item.mediaFileId;
    final shortBound =
        boundId == null || boundId.length < 10
            ? boundId
            : "${boundId.substring(0, 8)}…";
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Основной файл контента",
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              boundId == null
                  ? "Файл для чтения или воспроизведения не привязан."
                  : "Привязан media_file_id: $shortBound",
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<MediaFileSummary>>(
              future: _filesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: LinearProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
                final all = snapshot.data ?? const <MediaFileSummary>[];
                final choices = all
                    .where(
                      (f) =>
                          f.uploadStatus == "ready" &&
                          _isCompatibleContentType(f.contentType),
                    )
                    .toList(growable: false);
                if (choices.isEmpty) {
                  return Text(
                    "Нет готовых файлов подходящего типа. Загрузите файл ниже.",
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                String? dropdownValue;
                if (boundId != null && choices.any((c) => c.id == boundId)) {
                  dropdownValue = boundId;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Привязать загруженный файл",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: dropdownValue,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: "Файл в хранилище",
                      ),
                      hint: const Text("Выберите файл"),
                      items: choices
                          .map(
                            (f) => DropdownMenuItem(
                              value: f.id,
                              child: Text(
                                "${f.contentType} · ${_OwnerMainMediaFileCardState._shortenUuid(f.id)}",
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged:
                          _busy
                              ? null
                              : (value) {
                                if (value != null) {
                                  unawaited(_bindExisting(value, context));
                                }
                              },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pickAndUpload(context),
                    icon:
                        _busy
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.upload_file_outlined),
                    label: const Text("Загрузить и привязать"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _shortenUuid(String id) {
    if (id.length <= 10) {
      return id;
    }
    return "${id.substring(0, 8)}…";
  }
}
