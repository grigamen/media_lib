import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sqflite/sqflite.dart";

/// Сохраняет текст книги в каталог приложения для офлайн-чтения.
Future<String?> writeBookOfflinePlainText({
  required String userId,
  required String mediaItemId,
  required String plainText,
}) async {
  final baseDir = await getDatabasesPath();
  final bookDir = Directory(p.join(baseDir, "book_offline", userId));
  if (!await bookDir.exists()) {
    await bookDir.create(recursive: true);
  }
  final safeId = mediaItemId.replaceAll(RegExp(r'[^\w\-.]'), "_");
  final file = File(p.join(bookDir.path, "$safeId.txt"));
  await file.writeAsString(plainText, encoding: utf8);
  return file.path;
}
