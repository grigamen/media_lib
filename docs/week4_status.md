# Week 4 Status (backend: Progress + Files/S3)

## Что сделано

- Добавлены SQLAlchemy-модели:
  - `progress`
  - `media_files`
- Добавлена и применена миграция:
  - `backend/alembic/versions/a4f2c9d1e7b0_add_progress_and_media_files.py`
  - команда: `.\.venv\Scripts\python.exe -m alembic upgrade head`
- Реализованы API endpoint'ы:
  - `GET /media-items/{media_item_id}/progress`
  - `PUT /media-items/{media_item_id}/progress`
  - `POST /media-items/{media_item_id}/files/upload`
  - `POST /media-files/{file_id}/complete`
  - `GET /media-files/{file_id}/stream`
- Добавлены базовые ограничения upload:
  - whitelist `content_type`
  - лимит `MAX_UPLOAD_FILE_SIZE_BYTES`
- Добавлены тестовые сценарии в `backend/tests/test_media.py`:
  - progress get/put flow
  - upload -> complete -> stream flow
  - stream до complete (409)
  - unsupported content type (400)
  - oversized file (400)
  - e2e: upload -> stream -> save progress

## Текущее качество

- Backend-тесты:
  - `15 passed`
- Обратная совместимость:
  - существующие auth/media endpoint'ы сохранены

## Следующие шаги (Week 5)

- Перейти к mobile-блоку:
  - auth flow на клиенте
  - базовые экраны библиотеки/профиля
  - интеграция mobile с backend auth/catalog API
