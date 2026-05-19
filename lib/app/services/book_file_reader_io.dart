import "dart:io";

Future<List<int>?> readLocalBookFileBytes(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    return null;
  }
  return file.readAsBytes();
}
