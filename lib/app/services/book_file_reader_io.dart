import "dart:io";

Future<List<int>?> readLocalBookFileBytes(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    return null;
  }
  return file.readAsBytes();
}

Future<bool> localBookFileExists(String filePath) async {
  final file = File(filePath);
  return file.exists();
}

Future<void> deleteLocalBookFile(String filePath) async {
  final file = File(filePath);
  if (await file.exists()) {
    await file.delete();
  }
}
