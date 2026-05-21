import "package:flutter/material.dart";

/// Стандартная заглушка, если у произведения нет обложки.
class MediaCoverPlaceholder extends StatelessWidget {
  const MediaCoverPlaceholder({super.key, this.iconSize = 48});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.auto_stories_outlined,
          size: iconSize,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

/// Обложка произведения или заглушка при отсутствии / ошибке загрузки.
class MediaCoverImage extends StatelessWidget {
  const MediaCoverImage({
    super.key,
    required this.coverUrl,
    this.fit = BoxFit.cover,
  });

  final String? coverUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl?.trim();
    if (url == null || url.isEmpty) {
      return MediaCoverPlaceholder(iconSize: fit == BoxFit.cover ? 48 : 32);
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder:
          (_, __, ___) =>
              MediaCoverPlaceholder(iconSize: fit == BoxFit.cover ? 48 : 32),
    );
  }
}
