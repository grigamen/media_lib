import "package:flutter/material.dart";

import "../data/library_repository.dart";

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.items,
    required this.usingDemoItems,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.searchQuery,
    required this.typeFilter,
    required this.onApplyFilters,
    required this.onAddItem,
    required this.onLoadLinks,
    required this.onLoadItemById,
    super.key,
  });

  final List<MediaListItem> items;
  final bool usingDemoItems;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final String searchQuery;
  final String? typeFilter;
  final Future<void> Function(String searchQuery, String? typeFilter) onApplyFilters;
  final Future<void> Function(String type, String title, String? author) onAddItem;
  final Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks;
  final Future<MediaListItem?> Function(String mediaItemId) onLoadItemById;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  List<_WorkGroup> _buildWorkGroups(List<MediaListItem> items) {
    final groups = <String, List<MediaListItem>>{};
    for (final item in items) {
      final key =
          "${item.title.trim().toLowerCase()}::${(item.author ?? "").trim().toLowerCase()}";
      groups.putIfAbsent(key, () => <MediaListItem>[]).add(item);
    }
    final result = groups.values
        .map((groupItems) => _WorkGroup(groupItems: groupItems))
        .toList(growable: false);
    result.sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
    return result;
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery && _searchController.text != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    String selectedType = "book";
    String? submitError;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              setDialogState(() {
                isSubmitting = true;
                submitError = null;
              });
              try {
                await widget.onAddItem(
                  selectedType,
                  titleController.text.trim(),
                  authorController.text.trim().isEmpty ? null : authorController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } catch (_) {
                setDialogState(() {
                  submitError = "Не удалось добавить контент";
                  isSubmitting = false;
                });
              }
            }

            return AlertDialog(
              title: const Text("Добавить контент"),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: "book", child: Text("Книга")),
                        DropdownMenuItem(value: "audiobook", child: Text("Аудиокнига")),
                        DropdownMenuItem(value: "video", child: Text("Видео")),
                      ],
                      onChanged: isSubmitting
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedType = value;
                                });
                              }
                            },
                      decoration: const InputDecoration(labelText: "Тип"),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleController,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(labelText: "Название"),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? "Укажите название" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: authorController,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(labelText: "Автор (опционально)"),
                    ),
                    if (submitError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        submitError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text("Отмена"),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Сохранить"),
                ),
              ],
            );
          },
        );
      },
    );
    titleController.dispose();
    authorController.dispose();
  }

  Future<void> _showLinksDialog(MediaListItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return FutureBuilder<List<MediaLinkItem>>(
          future: widget.onLoadLinks(item.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text("Не удалось загрузить связи")),
              );
            }
            final links = snapshot.data ?? const <MediaLinkItem>[];
            if (links.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text("Связей пока нет")),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final link = links[index];
                return ListTile(
                  leading: const Icon(Icons.link),
                  title: Text("Тип связи: ${link.relationType}"),
                  subtitle: Text("source: ${link.sourceMediaId}\ntarget: ${link.targetMediaId}"),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemCount: links.length,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Builder(
        builder: (context) {
          if (widget.isLoading && widget.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (widget.errorMessage != null && widget.items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _LibraryControls(
                  searchController: _searchController,
                  typeFilter: widget.typeFilter,
                  onApplyFilters: widget.onApplyFilters,
                  onAddPressed: _showAddDialog,
                ),
                const SizedBox(height: 64),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      widget.errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }
          if (widget.items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _LibraryControls(
                  searchController: _searchController,
                  typeFilter: widget.typeFilter,
                  onApplyFilters: widget.onApplyFilters,
                  onAddPressed: _showAddDialog,
                ),
                const SizedBox(height: 64),
                Center(
                  child: Text(
                    widget.usingDemoItems
                        ? "Тестовые произведения не найдены по текущему фильтру"
                        : "Библиотека пока пустая",
                  ),
                ),
              ],
            );
          }
          final groups = _buildWorkGroups(widget.items);
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LibraryControls(
                      searchController: _searchController,
                      typeFilter: widget.typeFilter,
                      onApplyFilters: widget.onApplyFilters,
                      onAddPressed: _showAddDialog,
                    ),
                    if (widget.usingDemoItems) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Показаны тестовые произведения (backend вернул пустую библиотеку).",
                        ),
                      ),
                    ],
                  ],
                );
              }
              final group = groups[index - 1];
              final firstChar = group.displayTitle.isNotEmpty
                  ? group.displayTitle.substring(0, 1).toUpperCase()
                  : "?";
              return ListTile(
                leading: CircleAvatar(child: Text(firstChar)),
                title: Text(group.displayTitle),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (group.displayAuthor.isNotEmpty) Text(group.displayAuthor),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: -8,
                      children: group.types
                          .map(
                            (type) => Chip(
                              label: Text(_labelForType(type)),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
                isThreeLine: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _MediaItemDetailsPage(
                        group: group,
                        onLoadLinks: widget.onLoadLinks,
                        onLoadItemById: widget.onLoadItemById,
                      ),
                    ),
                  );
                },
                trailing: IconButton(
                  tooltip: "Связи",
                  icon: const Icon(Icons.link),
                  onPressed: () => _showLinksDialog(group.primaryItem),
                ),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemCount: groups.length + 1,
          );
        },
      ),
    );
  }
}

String _labelForType(String type) {
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

class _WorkGroup {
  _WorkGroup({required this.groupItems});

  final List<MediaListItem> groupItems;

  MediaListItem get primaryItem => groupItems.first;
  String get displayTitle => primaryItem.title;
  String get displayAuthor => primaryItem.author ?? "";
  List<String> get types =>
      groupItems.map((item) => item.type).toSet().toList(growable: false)..sort();
}

class _LibraryControls extends StatelessWidget {
  const _LibraryControls({
    required this.searchController,
    required this.typeFilter,
    required this.onApplyFilters,
    required this.onAddPressed,
  });

  final TextEditingController searchController;
  final String? typeFilter;
  final Future<void> Function(String searchQuery, String? typeFilter) onApplyFilters;
  final Future<void> Function() onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchController,
          onSubmitted: (_) => onApplyFilters(searchController.text.trim(), typeFilter),
          decoration: InputDecoration(
            hintText: "Поиск по названию/автору",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: () => onApplyFilters(searchController.text.trim(), typeFilter),
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: typeFilter ?? "all",
                items: const [
                  DropdownMenuItem(value: "all", child: Text("Все типы")),
                  DropdownMenuItem(value: "book", child: Text("Книги")),
                  DropdownMenuItem(value: "audiobook", child: Text("Аудиокниги")),
                  DropdownMenuItem(value: "video", child: Text("Видео")),
                ],
                onChanged: (value) {
                  final selected = value == null || value == "all" ? null : value;
                  onApplyFilters(searchController.text.trim(), selected);
                },
                decoration: const InputDecoration(labelText: "Фильтр по типу"),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text("Добавить"),
            ),
          ],
        ),
      ],
    );
  }
}

class _MediaItemDetailsPage extends StatefulWidget {
  const _MediaItemDetailsPage({
    required this.group,
    required this.onLoadLinks,
    required this.onLoadItemById,
  });

  final _WorkGroup group;
  final Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks;
  final Future<MediaListItem?> Function(String mediaItemId) onLoadItemById;

  @override
  State<_MediaItemDetailsPage> createState() => _MediaItemDetailsPageState();
}

class _MediaItemDetailsPageState extends State<_MediaItemDetailsPage> {
  late List<MediaListItem> _variants;
  bool _isLoadingLinked = false;

  @override
  void initState() {
    super.initState();
    _variants = List<MediaListItem>.from(widget.group.groupItems);
    _loadLinkedVariants();
  }

  Future<void> _loadLinkedVariants() async {
    setState(() {
      _isLoadingLinked = true;
    });

    final knownIds = _variants.map((item) => item.id).toSet();
    final linkedIds = <String>{};
    for (final item in _variants) {
      final links = await widget.onLoadLinks(item.id);
      for (final link in links) {
        linkedIds.add(link.sourceMediaId);
        linkedIds.add(link.targetMediaId);
      }
    }

    for (final id in linkedIds) {
      if (knownIds.contains(id)) {
        continue;
      }
      final linkedItem = await widget.onLoadItemById(id);
      if (linkedItem != null) {
        _variants.add(linkedItem);
        knownIds.add(linkedItem.id);
      }
    }

    if (mounted) {
      _variants.sort((a, b) => a.type.compareTo(b.type));
      setState(() {
        _isLoadingLinked = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.group.displayTitle;
    final author = widget.group.displayAuthor;
    if (_variants.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text("Нет доступных форм произведения")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: DefaultTabController(
        length: _variants.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text("Автор: ${author.isNotEmpty ? author : "Не указан"}"),
                  if (_isLoadingLinked) ...[
                    const SizedBox(height: 6),
                    const Text("Загружаем связанные формы произведения..."),
                  ],
                ],
              ),
            ),
            TabBar(
              isScrollable: true,
              tabs: _variants
                  .map((item) => Tab(text: _labelForType(item.type)))
                  .toList(growable: false),
            ),
            Expanded(
              child: TabBarView(
                children: _variants
                    .map(
                      (item) => ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text("Тип: ${_labelForType(item.type)}"),
                          const SizedBox(height: 6),
                          Text("Название: ${item.title}"),
                          const SizedBox(height: 6),
                          Text("Автор: ${item.author?.isNotEmpty == true ? item.author : "Не указан"}"),
                          const SizedBox(height: 12),
                          Text(
                            item.description?.isNotEmpty == true
                                ? item.description!
                                : "Описание отсутствует",
                          ),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
