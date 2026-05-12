import "package:file_picker/file_picker.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "../data/library_repository.dart";
import "../../../app/app_state.dart";
import "../../../core/network/api_client.dart";

List<String> _uniqueGenres(Iterable<String> genres) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in genres) {
    final genre = raw.trim();
    if (genre.isEmpty) {
      continue;
    }
    final key = genre.toLowerCase();
    if (seen.contains(key)) {
      continue;
    }
    seen.add(key);
    result.add(genre);
  }
  return result;
}

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({
    required this.onAddItem,
    required this.availableGenres,
    super.key,
  });

  final Future<MediaListItem?> Function({
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    MediaUploadPayload? uploadPayload,
  })
  onAddItem;
  final List<String> availableGenres;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedType = "book";
  String? _selectedFileName;
  String? _selectedFileMime;
  MediaUploadPayload? _selectedFileUpload;
  MediaUploadPayload? _selectedCoverUpload;
  List<String> _selectedGenres = [];
  String? _genrePickerValue;
  bool _isSubmitting = false;
  bool _isPickingFile = false;
  bool _isPickingCover = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      if (_selectedFileName != null &&
          !_isFileCompatibleWithType(
            filename: _selectedFileName,
            mimeType: _selectedFileMime,
            mediaType: _selectedType,
          )) {
        setState(() {
          _error = "Выбранный файл не подходит для типа $_selectedType";
          _isSubmitting = false;
        });
        return;
      }
      final requiresUpload =
          _selectedType == "audiobook" || _selectedType == "video";
      if (requiresUpload &&
          (_selectedFileName == null || _selectedFileUpload == null)) {
        setState(() {
          _error = "Для аудиокниги и видео нужно выбрать файл";
          _isSubmitting = false;
        });
        return;
      }
      final created = await widget.onAddItem(
        type: _selectedType,
        title: _titleController.text.trim(),
        author:
            _authorController.text.trim().isEmpty
                ? null
                : _authorController.text.trim(),
        genres: _selectedGenres.isEmpty ? null : _selectedGenres,
        coverUploadPayload: _selectedCoverUpload,
        uploadPayload:
            _selectedFileName != null && _selectedFileUpload != null
                ? _selectedFileUpload
                : null,
      );
      if (!mounted) {
        return;
      }
      _titleController.clear();
      _authorController.clear();
      _selectedFileName = null;
      _selectedFileMime = null;
      _selectedFileUpload = null;
      _selectedCoverUpload = null;
      _selectedGenres = [];
      _genrePickerValue = null;
      final msg =
          created?.moderationStatus == "pending"
              ? "Произведение отправлено на модерацию"
              : "Произведение добавлено";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _error = "Не удалось добавить произведение";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    if (_isSubmitting || _isPickingFile) {
      return;
    }
    _isPickingFile = true;
    final allowedExtensions =
        _selectedType == "audiobook"
            ? const ["mp3", "m4a", "aac", "wav", "ogg"]
            : _selectedType == "video"
            ? const ["mp4", "mkv", "webm", "mov", "avi"]
            : const ["txt", "md", "pdf", "epub", "docx"];
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: kIsWeb,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.first;
      final inferred =
          _inferContentTypeFromName(file.name) ??
          _fallbackContentType(_selectedType);
      final payload = MediaUploadPayload.tryFromPlatformFile(
        file: file,
        contentType: inferred,
      );
      if (payload == null) {
        setState(() {
          _error = "Не удалось прочитать выбранный файл";
        });
        return;
      }
      setState(() {
        _selectedFileName = file.name;
        _selectedFileMime = inferred;
        _selectedFileUpload = payload;
        _error = null;
      });
    } finally {
      _isPickingFile = false;
    }
  }

  Future<void> _pickCoverFile() async {
    if (_isSubmitting || _isPickingCover) {
      return;
    }
    _isPickingCover = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ["jpg", "jpeg", "png", "webp"],
        withData: kIsWeb,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.first;
      final mime = _inferImageContentTypeFromName(file.name) ?? "image/jpeg";
      final payload = MediaUploadPayload.tryFromPlatformFile(
        file: file,
        contentType: mime,
      );
      if (payload == null) {
        setState(() {
          _error = "Не удалось прочитать файл обложки";
        });
        return;
      }
      setState(() {
        _selectedCoverUpload = payload;
        _error = null;
      });
    } finally {
      _isPickingCover = false;
    }
  }

  String _fallbackContentType(String mediaType) {
    if (mediaType == "book") {
      return "text/plain";
    }
    if (mediaType == "audiobook") {
      return "audio/mpeg";
    }
    if (mediaType == "video") {
      return "video/mp4";
    }
    return "application/octet-stream";
  }

  bool _isFileCompatibleWithType({
    required String? filename,
    required String? mimeType,
    required String mediaType,
  }) {
    if (filename == null) {
      return true;
    }
    final normalizedMime =
        (mimeType ?? _inferContentTypeFromName(filename) ?? "")
            .trim()
            .toLowerCase();
    if (mediaType == "audiobook") {
      return normalizedMime.startsWith("audio/");
    }
    if (mediaType == "video") {
      return normalizedMime.startsWith("video/");
    }
    if (mediaType == "book") {
      return normalizedMime == "text/plain" ||
          normalizedMime == "text/markdown" ||
          normalizedMime == "application/pdf" ||
          normalizedMime == "application/epub+zip" ||
          normalizedMime ==
              "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    }
    return true;
  }

  String? _inferContentTypeFromName(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith(".txt")) return "text/plain";
    if (lower.endsWith(".md")) return "text/markdown";
    if (lower.endsWith(".pdf")) return "application/pdf";
    if (lower.endsWith(".epub")) return "application/epub+zip";
    if (lower.endsWith(".docx")) {
      return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    }
    if (lower.endsWith(".mp3")) return "audio/mpeg";
    if (lower.endsWith(".m4a")) return "audio/mp4";
    if (lower.endsWith(".aac")) return "audio/aac";
    if (lower.endsWith(".wav")) return "audio/wav";
    if (lower.endsWith(".ogg")) return "audio/ogg";
    if (lower.endsWith(".mp4")) return "video/mp4";
    if (lower.endsWith(".webm")) return "video/webm";
    if (lower.endsWith(".mov")) return "video/quicktime";
    if (lower.endsWith(".mkv")) return "video/x-matroska";
    if (lower.endsWith(".avi") || lower.endsWith(".avl")) {
      return "video/x-msvideo";
    }
    return null;
  }

  String? _inferImageContentTypeFromName(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
      return "image/jpeg";
    }
    if (lower.endsWith(".png")) {
      return "image/png";
    }
    if (lower.endsWith(".webp")) {
      return "image/webp";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final genreOptions = _uniqueGenres(widget.availableGenres);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          children: [
            Text(
              "Добавить произведение",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text("Тип контента", style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: "book",
                  icon: Icon(Icons.menu_book),
                  label: Text("Книга"),
                ),
                ButtonSegment(
                  value: "audiobook",
                  icon: Icon(Icons.headphones),
                  label: Text("Аудиокнига"),
                ),
                ButtonSegment(
                  value: "video",
                  icon: Icon(Icons.videocam_outlined),
                  label: Text("Видео"),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedType = selection.first;
                  _selectedFileName = null;
                  _selectedFileMime = null;
                  _selectedFileUpload = null;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 18),
            Text("Файл", style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: (_isSubmitting || _isPickingFile) ? null : _pickFile,
              child: Container(
                height: 210,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.upload_outlined, size: 30),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFileName == null
                            ? "Выбрать файл"
                            : _selectedFileName!,
                      ),
                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "${_selectedFileMime ?? "unknown"} • ${_selectedFileUpload?.byteLength ?? 0} bytes",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text("Обложка", style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: (_isSubmitting || _isPickingCover) ? null : _pickCoverFile,
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_outlined, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        _selectedCoverUpload == null
                            ? "Выбрать обложку"
                            : _selectedCoverUpload!.filename,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Название",
                      hintText: "Введите название",
                    ),
                    validator:
                        (value) =>
                            (value == null || value.trim().isEmpty)
                                ? "Введите название"
                                : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _authorController,
                    decoration: const InputDecoration(
                      labelText: "Автор",
                      hintText: "Введите автора",
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey("screen-genre-${_selectedGenres.join("|")}"),
                    value: _genrePickerValue,
                    items: genreOptions
                        .where(
                          (genre) =>
                              !_selectedGenres.any(
                                (selected) =>
                                    selected.toLowerCase() ==
                                    genre.toLowerCase(),
                              ),
                        )
                        .map(
                          (genre) => DropdownMenuItem(
                            value: genre,
                            child: Text(genre),
                          ),
                        )
                        .toList(growable: false),
                    onChanged:
                        _isSubmitting
                            ? null
                            : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedGenres = [..._selectedGenres, value];
                                _genrePickerValue = null;
                              });
                            },
                    decoration: const InputDecoration(
                      labelText: "Добавить жанр",
                      hintText: "Выберите жанр",
                    ),
                  ),
                  if (_selectedGenres.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedGenres
                          .map(
                            (genre) => InputChip(
                              label: Text(genre),
                              onDeleted:
                                  _isSubmitting
                                      ? null
                                      : () {
                                        setState(() {
                                          _selectedGenres = _selectedGenres
                                              .where((g) => g != genre)
                                              .toList(growable: false);
                                        });
                                      },
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child:
                          _isSubmitting
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text("Сохранить"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
