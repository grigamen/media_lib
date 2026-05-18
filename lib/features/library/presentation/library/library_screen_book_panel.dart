part of 'library_screen.dart';

// Текст и кнопка «Читать»: по нажатию открывается отдельный экран читалки с сохранением места в тексте.

/// Небольшой блок под книгой: объясняем и ведём на экран чтения.
class _BookReadLaunchPanel extends StatelessWidget {
  const _BookReadLaunchPanel({
    required this.item,
    required this.onOpenReader,
  });

  final MediaListItem item;
  final VoidCallback onOpenReader;

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
          "Текст открывается на отдельном экране с постраничной навигацией и сохранением позиции.",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onOpenReader,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text("Читать"),
        ),
      ],
    );
  }
}
