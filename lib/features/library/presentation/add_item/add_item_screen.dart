import "package:file_picker/file_picker.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "../../data/library_repository.dart";
import "../../../../app/app_state.dart";
import "../../../../core/files/media_upload_file_pick.dart";
import "../../../../core/network/api_client.dart";

// Экран создания произведения: тип контента, метаданные, обложка и основной файл с валидацией перед API.

part "add_item_fields.dart";
part "add_item_logic.dart";

/// Дедупликация жанров по строке без учёта регистра.
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

/// Форма добавления медиа в библиотеку текущего пользователя.
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

/// [AddItemScreen] с полями формы ([_AddItemScreenFields]) и логикой отправки ([_AddItemScreenLogic]).
class _AddItemScreenState extends State<AddItemScreen>
    with _AddItemScreenFields, _AddItemScreenLogic {
  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
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
