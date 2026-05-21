import "package:flutter/material.dart";

import "../../library/data/library_repository.dart";

// Экран администратора: модерация новых записей и каталог для удаления, с пагинацией.

const Duration _kAdminSnackShort = Duration(seconds: 2);

const Duration _kAdminSnackError = Duration(seconds: 3);

/// Сбрасывает очередь SnackBar — иначе при быстрых действиях они «настакиваются».
void _showAdminSnackBar(BuildContext context, SnackBar snackBar) {
  final messenger = ScaffoldMessenger.of(context);

  messenger.clearSnackBars();

  messenger.showSnackBar(snackBar);
}

enum _AdminListKind {
  /// Только одобрение / отклонение.
  moderation,

  /// Каталог для удаления (без записей «на модерации»).
  deletion,
}

/// Две вкладки: очередь модерации и полный список; подтверждения через SnackBar без наложения.
class AdminMediaScreen extends StatelessWidget {
  const AdminMediaScreen({
    required this.pendingItems,

    required this.allItems,

    required this.pendingCommentReports,

    required this.isLoading,

    required this.isLoadingMorePending,

    required this.hasMorePending,

    required this.isLoadingMoreAll,

    required this.hasMoreAll,

    required this.isCommentReportsLoading,

    required this.isCommentReportsLoadingMore,

    required this.hasMoreCommentReports,

    required this.errorMessage,

    required this.commentReportsError,

    required this.onRefresh,

    required this.onRefreshCommentReports,

    required this.onLoadMorePending,

    required this.onLoadMoreAll,

    required this.onLoadMoreCommentReports,

    required this.onDeleteItem,

    required this.onModerateItem,

    required this.onDismissCommentReport,

    required this.onResolveCommentReport,

    required this.onOpenItem,

    super.key,
  });

  final List<MediaListItem> pendingItems;

  final List<MediaListItem> allItems;

  final List<CommentReportItem> pendingCommentReports;

  final bool isLoading;

  final bool isLoadingMorePending;

  final bool hasMorePending;

  final bool isLoadingMoreAll;

  final bool hasMoreAll;

  final bool isCommentReportsLoading;

  final bool isCommentReportsLoadingMore;

  final bool hasMoreCommentReports;

  final String? errorMessage;

  final String? commentReportsError;

  final Future<void> Function() onRefresh;

  final Future<void> Function() onRefreshCommentReports;

  final Future<void> Function() onLoadMorePending;

  final Future<void> Function() onLoadMoreAll;

  final Future<void> Function() onLoadMoreCommentReports;

  final Future<bool> Function(String mediaItemId) onDeleteItem;

  final Future<bool> Function(String mediaItemId, bool approve) onModerateItem;

  final Future<bool> Function(String reportId) onDismissCommentReport;

  final Future<bool> Function(String reportId) onResolveCommentReport;

  final Future<void> Function(MediaListItem item) onOpenItem;

  static String _typeRu(String type) {
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

  static String _moderationRu(String status) {
    switch (status) {
      case "pending":
        return "На модерации";

      case "rejected":
        return "Отклонено";

      case "approved":
        return "Одобрено";

      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,

      child: Scaffold(
        appBar: AppBar(
          title: const Text("Администрирование"),

          bottom: const TabBar(
            tabs: [
              Tab(text: "Подтверждение"),
              Tab(text: "Удаление"),
              Tab(text: "Жалобы"),
            ],
          ),
        ),

        body: TabBarView(
          children: [
            _AdminMediaTabPage(
              listKind: _AdminListKind.moderation,

              items: pendingItems,

              isLoading: isLoading,

              errorMessage: errorMessage,

              onRefresh: onRefresh,

              onDeleteItem: onDeleteItem,

              onModerateItem: onModerateItem,

              onOpenItem: onOpenItem,

              tabKeyPrefix: "p",

              showLoadMoreFooter: hasMorePending,

              isLoadingMore: isLoadingMorePending,

              onLoadMore: onLoadMorePending,

              intro:
                  "Произведения со статусом «На модерации» (постраничная загрузка с сервера; при большой очереди нажмите «Загрузить ещё»). "
                  "Одобрите публикацию или отклоните. После одобрения запись станет видна всем пользователям.",

              emptyMessage: "Нет произведений на модерации",
            ),

            _AdminMediaTabPage(
              listKind: _AdminListKind.deletion,

              items: allItems,

              isLoading: isLoading,

              errorMessage: errorMessage,

              onRefresh: onRefresh,

              onDeleteItem: onDeleteItem,

              onModerateItem: onModerateItem,

              onOpenItem: onOpenItem,

              tabKeyPrefix: "a",

              showLoadMoreFooter: hasMoreAll,

              isLoadingMore: isLoadingMoreAll,

              onLoadMore: onLoadMoreAll,

              intro:
                  "Одобренные и отклонённые произведения (постранично). На вкладке «Подтверждение» обрабатывается очередь модерации. "
                  "Здесь можно только удалить запись на сервере (soft delete).",

              emptyMessage: "Нет произведений в каталоге",
            ),

            _AdminCommentReportsTabPage(
              reports: pendingCommentReports,
              isLoading: isCommentReportsLoading,
              errorMessage: commentReportsError,
              onRefresh: onRefreshCommentReports,
              showLoadMoreFooter: hasMoreCommentReports,
              isLoadingMore: isCommentReportsLoadingMore,
              onLoadMore: onLoadMoreCommentReports,
              onDismissReport: onDismissCommentReport,
              onResolveReport: onResolveCommentReport,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMediaTabPage extends StatelessWidget {
  const _AdminMediaTabPage({
    required this.listKind,

    required this.items,

    required this.isLoading,

    required this.errorMessage,

    required this.onRefresh,

    required this.onDeleteItem,

    required this.onModerateItem,

    required this.onOpenItem,

    required this.tabKeyPrefix,

    required this.intro,

    required this.emptyMessage,

    this.showLoadMoreFooter = false,

    this.isLoadingMore = false,

    this.onLoadMore,
  });

  final _AdminListKind listKind;

  final List<MediaListItem> items;

  final bool isLoading;

  final String? errorMessage;

  final Future<void> Function() onRefresh;

  final Future<bool> Function(String mediaItemId) onDeleteItem;

  final Future<bool> Function(String mediaItemId, bool approve) onModerateItem;

  final Future<void> Function(MediaListItem item) onOpenItem;

  final String tabKeyPrefix;

  final bool showLoadMoreFooter;

  final bool isLoadingMore;

  final Future<void> Function()? onLoadMore;

  final String intro;

  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final visible = items;

    return RefreshIndicator(
      onRefresh: onRefresh,

      child:
          isLoading && visible.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(12),

                children: [
                  if (errorMessage != null) ...[
                    Text(
                      errorMessage!,

                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],

                  Text(intro, style: Theme.of(context).textTheme.bodySmall),

                  const SizedBox(height: 12),

                  if (visible.isEmpty && !isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),

                      child: Center(child: Text(emptyMessage)),
                    )
                  else
                    ...visible.map(
                      (item) => Card(
                        key: ValueKey<String>("$tabKeyPrefix-${item.id}"),

                        child: ListTile(
                          onTap: () {
                            onOpenItem(item);
                          },

                          title: Text(item.title),

                          subtitle: Text(
                            "${AdminMediaScreen._typeRu(item.type)} · "
                            "${item.author?.trim().isNotEmpty == true ? item.author! : "без автора"}\n"
                            "${AdminMediaScreen._moderationRu(item.moderationStatus)}"
                            "${item.userId != null ? "\nuser_id: ${item.userId}" : ""}",
                          ),

                          isThreeLine: true,

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,

                            children: [
                              if (listKind == _AdminListKind.moderation &&
                                  item.moderationStatus == "pending") ...[
                                IconButton(
                                  tooltip: "Одобрить",

                                  icon: const Icon(Icons.check_circle_outline),

                                  onPressed: () async {
                                    final ok = await onModerateItem(
                                      item.id,

                                      true,
                                    );

                                    if (!context.mounted) {
                                      return;
                                    }

                                    _showAdminSnackBar(
                                      context,

                                      SnackBar(
                                        duration: _kAdminSnackShort,

                                        content: Text(
                                          ok
                                              ? "Произведение одобрено"
                                              : "Не удалось одобрить",
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                IconButton(
                                  tooltip: "Отклонить",

                                  icon: Icon(
                                    Icons.highlight_off_outlined,

                                    color: Theme.of(context).colorScheme.error,
                                  ),

                                  onPressed: () async {
                                    final ok =
                                        await showDialog<bool>(
                                          context: context,

                                          builder:
                                              (ctx) => AlertDialog(
                                                title: const Text(
                                                  "Отклонить произведение?",
                                                ),

                                                content: Text(
                                                  "«${item.title}» (${AdminMediaScreen._typeRu(item.type)})",
                                                ),

                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.of(
                                                          ctx,
                                                        ).pop(false),

                                                    child: const Text("Отмена"),
                                                  ),

                                                  FilledButton(
                                                    onPressed:
                                                        () => Navigator.of(
                                                          ctx,
                                                        ).pop(true),

                                                    child: const Text(
                                                      "Отклонить",
                                                    ),
                                                  ),
                                                ],
                                              ),
                                        ) ??
                                        false;

                                    if (!ok || !context.mounted) {
                                      return;
                                    }

                                    final done = await onModerateItem(
                                      item.id,

                                      false,
                                    );

                                    if (!context.mounted) {
                                      return;
                                    }

                                    _showAdminSnackBar(
                                      context,

                                      SnackBar(
                                        duration: _kAdminSnackShort,

                                        content: Text(
                                          done
                                              ? "Отклонено"
                                              : "Не удалось отклонить",
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],

                              if (listKind == _AdminListKind.deletion)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),

                                  onPressed: () async {
                                    final confirm =
                                        await showDialog<bool>(
                                          context: context,

                                          builder:
                                              (ctx) => AlertDialog(
                                                title: const Text(
                                                  "Удалить произведение?",
                                                ),

                                                content: Text(
                                                  "«${item.title}» (${AdminMediaScreen._typeRu(item.type)})",
                                                ),

                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.of(
                                                          ctx,
                                                        ).pop(false),

                                                    child: const Text("Отмена"),
                                                  ),

                                                  FilledButton(
                                                    onPressed:
                                                        () => Navigator.of(
                                                          ctx,
                                                        ).pop(true),

                                                    child: const Text(
                                                      "Удалить",
                                                    ),
                                                  ),
                                                ],
                                              ),
                                        ) ??
                                        false;

                                    if (!confirm || !context.mounted) {
                                      return;
                                    }

                                    final deleted = await onDeleteItem(item.id);

                                    if (!context.mounted) {
                                      return;
                                    }

                                    if (deleted) {
                                      _showAdminSnackBar(
                                        context,

                                        const SnackBar(
                                          duration: _kAdminSnackShort,

                                          content: Text("Произведение удалено"),
                                        ),
                                      );
                                    } else {
                                      _showAdminSnackBar(
                                        context,

                                        SnackBar(
                                          duration: _kAdminSnackError,

                                          content: const Text(
                                            "Не удалось удалить произведение",
                                          ),

                                          backgroundColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.error,
                                        ),
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (showLoadMoreFooter && onLoadMore != null) ...[
                    const SizedBox(height: 8),

                    Center(
                      child:
                          isLoadingMore
                              ? const Padding(
                                padding: EdgeInsets.all(12),

                                child: CircularProgressIndicator(),
                              )
                              : FilledButton.tonal(
                                onPressed: () async {
                                  await onLoadMore!();
                                },

                                child: const Text("Загрузить ещё"),
                              ),
                    ),
                  ],
                ],
              ),
    );
  }
}

class _AdminCommentReportsTabPage extends StatelessWidget {
  const _AdminCommentReportsTabPage({
    required this.reports,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onDismissReport,
    required this.onResolveReport,
    this.showLoadMoreFooter = false,
    this.isLoadingMore = false,
    this.onLoadMore,
  });

  final List<CommentReportItem> reports;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final Future<bool> Function(String reportId) onDismissReport;
  final Future<bool> Function(String reportId) onResolveReport;
  final bool showLoadMoreFooter;
  final bool isLoadingMore;
  final Future<void> Function()? onLoadMore;

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, "0");
    return "${two(local.day)}.${two(local.month)}.${local.year} "
        "${two(local.hour)}:${two(local.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child:
          isLoading && reports.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  if (errorMessage != null) ...[
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    "Жалобы пользователей на комментарии. Можно отклонить жалобу или удалить комментарий.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (reports.isEmpty && !isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: Text("Нет жалоб на модерации")),
                    )
                  else
                    ...reports.map(
                      (report) => Card(
                        key: ValueKey<String>("report-${report.id}"),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                report.mediaItemTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Автор комментария: ${report.commentAuthorDisplayName}",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                "Жалобу подал: ${report.reporterDisplayName} · ${_formatDate(report.createdAt)}",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(report.commentText),
                                ),
                              ),
                              if (report.reason?.trim().isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Text(
                                  "Причина: ${report.reason!.trim()}",
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final ok = await onDismissReport(
                                          report.id,
                                        );
                                        if (!context.mounted) {
                                          return;
                                        }
                                        _showAdminSnackBar(
                                          context,
                                          SnackBar(
                                            duration: _kAdminSnackShort,
                                            content: Text(
                                              ok
                                                  ? "Жалоба отклонена"
                                                  : "Не удалось отклонить жалобу",
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text("Отклонить"),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () async {
                                        final confirm =
                                            await showDialog<bool>(
                                              context: context,
                                              builder:
                                                  (ctx) => AlertDialog(
                                                    title: const Text(
                                                      "Удалить комментарий?",
                                                    ),
                                                    content: const Text(
                                                      "Комментарий будет удалён, связанные жалобы исчезнут.",
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed:
                                                            () =>
                                                                Navigator.of(
                                                                  ctx,
                                                                ).pop(false),
                                                        child: const Text(
                                                          "Отмена",
                                                        ),
                                                      ),
                                                      FilledButton(
                                                        onPressed:
                                                            () =>
                                                                Navigator.of(
                                                                  ctx,
                                                                ).pop(true),
                                                        child: const Text(
                                                          "Удалить",
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            ) ??
                                            false;
                                        if (!confirm || !context.mounted) {
                                          return;
                                        }
                                        final ok = await onResolveReport(
                                          report.id,
                                        );
                                        if (!context.mounted) {
                                          return;
                                        }
                                        _showAdminSnackBar(
                                          context,
                                          SnackBar(
                                            duration: _kAdminSnackShort,
                                            content: Text(
                                              ok
                                                  ? "Комментарий удалён"
                                                  : "Не удалось удалить комментарий",
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text("Удалить комментарий"),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (showLoadMoreFooter && onLoadMore != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child:
                          isLoadingMore
                              ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(),
                              )
                              : FilledButton.tonal(
                                onPressed: () async {
                                  await onLoadMore!();
                                },
                                child: const Text("Загрузить ещё"),
                              ),
                    ),
                  ],
                ],
              ),
    );
  }
}
