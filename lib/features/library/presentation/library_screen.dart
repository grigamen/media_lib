import "package:flutter/material.dart";

import "../data/library_repository.dart";

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    required this.items,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    super.key,
  });

  final List<MediaListItem> items;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Builder(
        builder: (context) {
          if (isLoading && items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (errorMessage != null && items.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text("Библиотека пока пустая")),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final item = items[index];
              final firstChar = item.type.isNotEmpty ? item.type.substring(0, 1).toUpperCase() : "?";
              return ListTile(
                leading: CircleAvatar(child: Text(firstChar)),
                title: Text(item.title),
                subtitle: Text(item.author?.isNotEmpty == true ? item.author! : item.type),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}
