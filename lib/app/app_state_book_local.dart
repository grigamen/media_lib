part of "app_state.dart";

/// Локальные копии книг: офлайн-скачивание для всех и файл автора на устройстве.
mixin _AppStateBookLocal on _AppStateRefs {
  Future<AuthorBookLocalSource?> resolveBookLocalSource(
    MediaListItem item,
  ) async {
    final userId = _s._currentUserId;
    if (userId == null || item.type != "book" || kIsWeb) {
      return null;
    }
    final store = _s._authorBookLocalStore;
    if (store == null) {
      return null;
    }
    final saved = await store.load(userId: userId, mediaItemId: item.id);
    if (saved == null) {
      return null;
    }
    final bytes = await readLocalBookFileBytes(saved.filePath);
    if (bytes == null || bytes.isEmpty) {
      await store.deleteForItem(userId: userId, mediaItemId: item.id);
      return null;
    }
    return saved;
  }

  Future<bool> hasBookOfflineCopy(String mediaItemId) async {
    final userId = _s._currentUserId;
    if (userId == null || kIsWeb) {
      return false;
    }
    final store = _s._authorBookLocalStore;
    if (store == null) {
      return false;
    }
    final saved = await store.load(userId: userId, mediaItemId: mediaItemId);
    if (saved == null) {
      return false;
    }
    final bytes = await readLocalBookFileBytes(saved.filePath);
    return bytes != null && bytes.isNotEmpty;
  }

  Future<bool> downloadBookForOffline(MediaListItem item) async {
    if (kIsWeb || item.type != "book" || item.id.startsWith("demo-")) {
      return false;
    }
    final userId = _s._currentUserId;
    final session = _s._session;
    final store = _s._authorBookLocalStore;
    if (userId == null || session == null || store == null) {
      return false;
    }
    final text = await _s._bookContentLoader.loadPlainTextForReading(
      item: item,
      session: session,
      resolveLocalSource: null,
    );
    final path = await writeBookOfflinePlainText(
      userId: userId,
      mediaItemId: item.id,
      plainText: text,
    );
    if (path == null || path.isEmpty) {
      return false;
    }
    final filename = _offlineBookFilename(item.title);
    await store.save(
      userId: userId,
      mediaItemId: item.id,
      filePath: path,
      filename: filename,
      contentType: "text/plain; charset=utf-8",
    );
    notifyListeners();
    return true;
  }

  Future<void> saveAuthorBookLocalFile({
    required String mediaItemId,
    required String filePath,
    required String filename,
    required String contentType,
  }) async {
    if (kIsWeb) {
      return;
    }
    final userId = _s._currentUserId;
    final store = _s._authorBookLocalStore;
    if (userId == null || store == null) {
      return;
    }
    await store.save(
      userId: userId,
      mediaItemId: mediaItemId,
      filePath: filePath,
      filename: filename,
      contentType: contentType,
    );
    notifyListeners();
  }

  void _persistAuthorBookLocalFileFromUpload({
    required String type,
    required String mediaItemId,
    required MediaUploadPayload uploadPayload,
  }) {
    if (type != "book" || kIsWeb) {
      return;
    }
    final path = uploadPayload.filePath;
    if (path == null || path.isEmpty) {
      return;
    }
    final contentType = MediaUploadPayload.resolvedMainFileContentType(
      filename: uploadPayload.filename,
      declaredContentType: uploadPayload.contentType,
      mediaItemType: type,
    );
    unawaited(
      saveAuthorBookLocalFile(
        mediaItemId: mediaItemId,
        filePath: path,
        filename: uploadPayload.filename,
        contentType: contentType,
      ),
    );
  }

  String _offlineBookFilename(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return "book.txt";
    }
    final safe = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), "_");
    return "$safe.txt";
  }
}
