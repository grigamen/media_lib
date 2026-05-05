# Неделя 4: Контрольная приемка (backend)

## Автотесты

- Команда:
  - `cd backend`
  - `.\.venv\Scripts\python.exe -m pytest -q`
- Результат:
  - `15 passed`

## Проверенные сценарии

- Прогресс просмотра/прослушивания:
  - `GET /media-items/{media_item_id}/progress` создает и возвращает дефолтный прогресс (если его еще нет).
  - `PUT /media-items/{media_item_id}/progress` делает upsert прогресса и корректно рассчитывает `progress_percent`.
- Файловый S3 flow:
  - `POST /media-items/{media_item_id}/files/upload` создает запись файла и возвращает presigned `PUT` URL.
  - `POST /media-files/{file_id}/complete` переводит файл в статус `ready`.
  - `GET /media-files/{file_id}/stream` возвращает presigned `GET` URL для стриминга.
- Базовые ограничения upload:
  - запрещены неподдерживаемые `content_type`.
  - ограничен максимальный размер файла (`MAX_UPLOAD_FILE_SIZE_BYTES`).
- Негативный сценарий:
  - запрос stream до `complete` возвращает `409`.
  - неподдерживаемый MIME и слишком большой файл возвращают `400`.
- Сквозной сценарий:
  - покрыт единым тестом `upload -> complete -> stream -> save progress`.

## Вывод

- Backend-блок Week 4 закрыт:
  - модель прогресса `progress`
  - модель файлов `media_files`
  - Alembic-миграция применена
  - API для `progress` и presigned URL flow (`upload/complete/stream`)
  - добавлены базовые ограничения по типу/размеру файла
  - проверен сквозной e2e-сценарий upload/play/progress
  - тесты и документация обновлены
