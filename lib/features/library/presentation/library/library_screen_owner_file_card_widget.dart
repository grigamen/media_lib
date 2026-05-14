part of 'library_screen.dart';

// Карточка «основной файл» в интерфейсе: сам виджет, а список и загрузка обрабатываются в связанном файле состояния.

/// Блок для автора: показать файлы и дать сменить основной или загрузить новый.
class _OwnerMainMediaFileCard extends StatefulWidget {
  const _OwnerMainMediaFileCard({
    required this.item,
    required this.onFetchFiles,
    required this.onBindFile,
    required this.onUploadAndBind,
    required this.onVariantRefreshed,
    required this.fallbackContentType,
    required this.inferContentTypeFromName,
    required this.isFileCompatibleWithType,
  });

  final MediaListItem item;
  final Future<List<MediaFileSummary>> Function(String mediaItemId)
  onFetchFiles;
  final Future<void> Function({
    required String mediaItemId,
    required String fileId,
  })
  onBindFile;
  final Future<void> Function({
    required String mediaItemId,
    required MediaUploadPayload uploadPayload,
  })
  onUploadAndBind;
  final Future<void> Function() onVariantRefreshed;
  final String Function(String mediaType) fallbackContentType;
  final String? Function(String filename) inferContentTypeFromName;
  final bool Function({
    required String? filename,
    required String? mimeType,
    required String mediaType,
  })
  isFileCompatibleWithType;

  @override
  State<_OwnerMainMediaFileCard> createState() =>
      _OwnerMainMediaFileCardState();
}
