import "package:file_picker/file_picker.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

/// Picks a file for upload. On Android, [file_picker] copies the selection into
/// app cache first (full file read/write), so large videos can take minutes with
/// no visible progress unless [onFileLoading] is used.
Future<FilePickerResult?> pickMediaFileForUpload({
  required BuildContext context,
  required List<String> allowedExtensions,
}) {
  return FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    withData: kIsWeb,
    compressionQuality: 0,
    onFileLoading: (status) => _notifyFilePickerProgress(context, status),
  );
}

void _notifyFilePickerProgress(BuildContext context, FilePickerStatus status) {
  if (!context.mounted) {
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  if (status == FilePickerStatus.picking) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              kIsWeb
                  ? "Загрузка файла…"
                  : "Копируем файл в приложение… Для больших видео это может занять несколько минут.",
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(minHeight: 6),
            ),
          ],
        ),
        duration: const Duration(minutes: 30),
      ),
    );
  } else {
    messenger.hideCurrentSnackBar();
  }
}
