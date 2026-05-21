part of "library_repository.dart";

/// Расширение [LibraryRepository]: цикл presigned-загрузки в S3 (init → PUT → complete).
const Duration _presignedUploadTimeout = Duration(minutes: 30);
const Duration _presignedReadResponseTimeout = Duration(minutes: 2);

extension LibraryRepositoryPresigned on LibraryRepository {
  /// Запрашивает у API [upload_url] и [file_id] для последующего PUT тела файла.
  Future<MediaUploadInitInfo> initiateFileUpload({
    required String accessToken,
    required String mediaItemId,
    required String filename,
    required String contentType,
    required int fileSize,
  }) async {
    final response = await _apiClient.postJson(
      "/media-items/$mediaItemId/files/upload",
      <String, dynamic>{
        "filename": filename,
        "content_type": contentType,
        "file_size": fileSize,
      },
      accessToken: accessToken,
    );
    return MediaUploadInitInfo.fromJson(response);
  }

  /// Guard: отсекает «заглушечные» AWS-креды в dev, чтобы ошибка была явной.
  void _ensurePresignedTargetConfigured(Uri targetUri) {
    final credential = targetUri.queryParameters["X-Amz-Credential"];
    if (credential != null && credential.startsWith("test-access-key/")) {
      throw ApiException(
        "S3 в backend не настроен: используется тестовый AWS ключ. "
        "Заполните S3_ENDPOINT_URL/AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY/S3_BUCKET в backend/.env.",
      );
    }
  }

  /// PUT тела из памяти на [uploadUrl] с таймаутом и опциональным прогрессом.
  Future<void> uploadBytesToPresignedUrl({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
    void Function(int uploaded, int total)? onProgress,
  }) async {
    final targetUri = _normalizeUploadUri(uploadUrl);
    _ensurePresignedTargetConfigured(targetUri);
    http.Response response;
    onProgress?.call(0, bytes.length);
    try {
      response = await http
          .put(
            targetUri,
            headers: <String, String>{"Content-Type": contentType},
            body: bytes,
          )
          .timeout(_presignedUploadTimeout);
    } on TimeoutException {
      throw ApiException("Таймаут при загрузке файла в хранилище");
    } on Exception {
      throw ApiException(
        "Не удалось загрузить файл в хранилище. "
        "Endpoint: ${targetUri.host}. "
        "Проверьте доступность S3 endpoint (для Android эмулятора используйте 10.0.2.2 вместо localhost).",
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        "Хранилище вернуло ошибку при загрузке файла: HTTP ${response.statusCode}",
        statusCode: response.statusCode,
      );
    }
    onProgress?.call(bytes.length, bytes.length);
  }

  /// Потоковая загрузка без удержания всего файла в памяти (важно для больших аудио/видео).
  ///
  /// [StreamedRequest.sink.addStream] уважает pause/resume сокета. Вариант
  /// `openRead().listen` + `sink.add` без backpressure раздувал буфер и мог
  /// «замирать» на больших MKV и т.п.
  Future<void> uploadFileToPresignedUrl({
    required String uploadUrl,
    required String filePath,
    required int contentLength,
    required String contentType,
    void Function(int uploaded, int total)? onProgress,
  }) async {
    final targetUri = _normalizeUploadUri(uploadUrl);
    _ensurePresignedTargetConfigured(targetUri);
    final file = File(filePath);
    if (!await file.exists()) {
      throw ApiException("Файл для загрузки не найден: $filePath");
    }
    final lengthOnDisk = await file.length();
    if (lengthOnDisk != contentLength) {
      throw ApiException(
        "Размер файла изменился ($lengthOnDisk байт, ожидалось $contentLength). "
        "Выберите файл заново.",
      );
    }

    final client = http.Client();
    try {
      final request = http.StreamedRequest("PUT", targetUri);
      request.headers["Content-Type"] = contentType;
      request.contentLength = contentLength;

      var uploaded = 0;
      final total = contentLength;
      onProgress?.call(0, total);

      final metered = file.openRead().transform<List<int>>(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            uploaded += data.length;
            final clamped = uploaded > total ? total : uploaded;
            onProgress?.call(clamped, total);
            sink.add(data);
          },
          handleError: (
            Object error,
            StackTrace stackTrace,
            EventSink<List<int>> sink,
          ) {
            sink.addError(error, stackTrace);
          },
        ),
      );

      final bodyDone = request.sink
          .addStream(metered)
          .then((_) => request.sink.close());
      late final http.StreamedResponse streamed;
      try {
        streamed = await client.send(request).timeout(_presignedUploadTimeout);
      } on TimeoutException {
        await bodyDone.catchError((_) {});
        throw ApiException("Таймаут при загрузке файла в хранилище");
      }
      await bodyDone;

      final response = await http.Response.fromStream(
        streamed,
      ).timeout(_presignedReadResponseTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          "Хранилище вернуло ошибку при загрузке файла: HTTP ${response.statusCode}",
          statusCode: response.statusCode,
        );
      }
      onProgress?.call(total, total);
    } on TimeoutException {
      throw ApiException("Таймаут при загрузке файла в хранилище");
    } on ApiException {
      rethrow;
    } on Exception {
      throw ApiException(
        "Не удалось загрузить файл в хранилище. "
        "Endpoint: ${targetUri.host}. "
        "Проверьте доступность S3 endpoint (для Android эмулятора используйте 10.0.2.2 вместо localhost).",
      );
    } finally {
      client.close();
    }
  }

  /// Сообщает серверу, что загрузка в bucket завершена ([upload_status] → ready).
  Future<void> completeFileUpload({
    required String accessToken,
    required String fileId,
  }) async {
    await _apiClient.postJson(
      "/media-files/$fileId/complete",
      const <String, dynamic>{},
      accessToken: accessToken,
    );
  }
}
