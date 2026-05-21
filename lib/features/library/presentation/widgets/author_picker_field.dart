import "dart:async";

import "package:flutter/material.dart";

import "../../data/library_models.dart";

/// Поле выбора автора: поиск по справочнику или создание нового объекта.
class AuthorPickerField extends StatefulWidget {
  const AuthorPickerField({
    required this.onSearchAuthors,
    required this.onCreateAuthor,
    required this.onChanged,
    this.onQueryChanged,
    this.initialAuthor,
    this.initialDisplayName,
    this.enabled = true,
    this.labelText = "Автор (опционально)",
    super.key,
  });

  final MediaAuthor? initialAuthor;
  final String? initialDisplayName;
  final bool enabled;
  final String labelText;
  final ValueChanged<MediaAuthor?> onChanged;
  final ValueChanged<String>? onQueryChanged;
  final Future<List<MediaAuthor>> Function(String query) onSearchAuthors;
  final Future<MediaAuthor> Function(String name) onCreateAuthor;

  @override
  State<AuthorPickerField> createState() => _AuthorPickerFieldState();
}

class _AuthorPickerFieldState extends State<AuthorPickerField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<MediaAuthor> _suggestions = const [];
  bool _loading = false;
  MediaAuthor? _selected;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialAuthor;
    if (_selected != null) {
      _controller.text = _selected!.name;
    } else {
      final legacyName = widget.initialDisplayName?.trim();
      if (legacyName != null && legacyName.isNotEmpty) {
        _controller.text = legacyName;
      }
    }
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant AuthorPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAuthor?.id != oldWidget.initialAuthor?.id) {
      _selected = widget.initialAuthor;
      _controller.text = _selected?.name ?? "";
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      setState(() {
        _showSuggestions = false;
        if (_selected != null) {
          _controller.text = _selected!.name;
        }
      });
      return;
    }
    setState(() {
      _showSuggestions = true;
    });
    _scheduleSearch(_controller.text);
  }

  void _scheduleSearch(String rawQuery) {
    _debounce?.cancel();
    final query = rawQuery.trim();
    if (query.isEmpty) {
      setState(() {
        _suggestions = const [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) {
        return;
      }
      setState(() => _loading = true);
      try {
        final results = await widget.onSearchAuthors(query);
        if (!mounted) {
          return;
        }
        setState(() {
          _suggestions = results;
          _loading = false;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _suggestions = const [];
          _loading = false;
        });
      }
    });
  }

  void _selectAuthor(MediaAuthor author) {
    setState(() {
      _selected = author;
      _controller.text = author.name;
      _suggestions = const [];
      _showSuggestions = false;
    });
    widget.onChanged(author);
    _focusNode.unfocus();
  }

  void _clearAuthor() {
    setState(() {
      _selected = null;
      _controller.clear();
      _suggestions = const [];
    });
    widget.onChanged(null);
  }

  Future<void> _createAuthor() async {
    final name = _controller.text.trim();
    if (name.isEmpty || !widget.enabled) {
      return;
    }
    setState(() => _loading = true);
    try {
      final created = await widget.onCreateAuthor(name);
      if (!mounted) {
        return;
      }
      _selectAuthor(created);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool get _canCreate {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return false;
    }
    final key = query.toLowerCase();
    return !_suggestions.any((author) => author.name.toLowerCase() == key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: "Найти или создать автора",
            suffixIcon:
                _loading
                    ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : _selected != null
                    ? IconButton(
                      tooltip: "Очистить",
                      onPressed: widget.enabled ? _clearAuthor : null,
                      icon: const Icon(Icons.clear),
                    )
                    : null,
          ),
          onChanged: (value) {
            widget.onQueryChanged?.call(value);
            if (_selected != null &&
                value.trim().toLowerCase() != _selected!.name.toLowerCase()) {
              _selected = null;
              widget.onChanged(null);
            }
            setState(() => _showSuggestions = _focusNode.hasFocus);
            _scheduleSearch(value);
          },
        ),
        if (_showSuggestions &&
            (_suggestions.isNotEmpty || _canCreate || _loading))
          Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surfaceContainerHighest,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  ..._suggestions.map(
                    (author) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline),
                      title: Text(author.name),
                      onTap: widget.enabled ? () => _selectAuthor(author) : null,
                    ),
                  ),
                  if (_canCreate)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add),
                      title: Text("Создать «${_controller.text.trim()}»"),
                      onTap: widget.enabled ? _createAuthor : null,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
