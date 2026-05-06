# Handoff для следующего агента

Продолжай проект **MediaLib** с текущего состояния после выполнения Week 7 Stage A.

## 1) Что прочитать в начале

- `docs/week7_status.md` (актуальный статус Week 7 stage A)
- `docs/week7_acceptance.md` (фактическая приемка Week 7 stage A)
- `docs/week6_status.md` (контекст перед стартом Week 7)
- `docs/week6_acceptance.md`
- `docs/week6_work_breakdown.md`
- `docs/week5_status.md` (контекст Week 5)
- `docs/week5_acceptance.md`
- `docs/week4_week5_fields_methods_reference.md` (поля и методы по Week 4-5)
- `docs/week1_work_breakdown.md` (детализация Week 1)
- `docs/week2_work_breakdown.md` (детализация Week 2)
- `docs/week3_work_breakdown.md` (детализация Week 3)
- `docs/week4_work_breakdown.md` (детализация Week 4)
- `docs/week5_work_breakdown.md` (детализация Week 5)
- `docs/week4_status.md` (контекст backend)
- `docs/week4_acceptance.md`
- `docs/week_plan_10_weeks.md` (полный согласованный план работ)
- `docs/week3_status.md` (контекст по Week 2-3)
- `docs/week3_catalog.md`
- `docs/week3_acceptance.md`

## 2) Что проверить перед началом новых правок

1. Проверить состояние дерева:
   - `git status`
2. Проверить backend тесты:
   - `cd backend`
   - `.\.venv\Scripts\python.exe -m pytest -q`
3. Ожидаемый результат тестов: `18 passed`.
4. Проверить mobile:
   - `cd ..` (в корень проекта)
   - `flutter analyze`
   - `flutter test`
5. Запуск мобильного приложения для ручной проверки:
   - `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000`

## 3) Текущее состояние проекта (кратко)

- Week 2 (Auth + 2FA): завершена.
- Week 3 (Каталог и связи): завершена.
- Week 4 (Progress + Files/S3): завершена.
  - добавлены модели `progress` и `media_files`;
  - добавлена и применена миграция `a4f2c9d1e7b0_add_progress_and_media_files`;
  - реализован API прогресса (`GET/PUT /media-items/{id}/progress`);
  - реализован presigned flow (`upload/complete/stream`);
  - добавлены ограничения upload (тип/размер);
  - добавлены e2e/негативные тесты.
- Актуальный backend-прогон: `18 passed`.
- Week 5 (Mobile Auth + базовый UI): завершена.
  - добавлена feature-структура `app/core/features`;
  - реализованы экраны auth/library/profile;
  - подключены backend API (`/auth/register`, `/auth/login`, `/media-items`);
  - настроены роутинг и состояния loading/error;
  - добавлено переключение светлой/темной темы;
  - `flutter analyze` и `flutter test` проходят.
- Week 6 (Mobile: библиотека, добавление, поиск): завершена.
  - реализовано добавление контента (`POST /media-items`);
  - добавлены поиск и фильтрация (`q` и `type`);
  - добавлен просмотр связей (`GET /media-items/{id}/links`) + загрузка связанных форм;
  - UI переведен на гибридную модель: одно произведение -> вкладки форматов;
  - добавлены fallback-демо произведения со всеми форматами (`book/audiobook/video`) при пустом backend-списке;
  - в API-клиент добавлены сетевые таймауты и понятные сообщения об ошибках вместо бесконечной загрузки;
  - `flutter analyze` и `flutter test` проходят.
- Week 7 Stage A (Mobile: playback + sync foundation): выполнен.
  - подключены `just_audio` и `video_player`;
  - реализован playback UI для `audiobook`/`video`;
  - добавлена скорость воспроизведения (`0.75x-2.0x`);
  - реализован flow восстановления и сохранения прогресса:
    - `GET /media-items/{id}/progress`
    - `PUT /media-items/{id}/progress`
    - `GET /media-files/{file_id}/stream`
  - добавлен периодический sync (10 сек) + flush на pause/complete/dispose;
  - добавлен pending-sync soft-fail при временных сетевых ошибках;
  - для demo-режима добавлены fallback stream URL;
  - ограничение: для backend media нужен `media_file_id` в `metadata_json`.

## 4) Следующая цель по плану: Week 7 Stage B / Stage C

Расширить playback до advanced-возможностей:

1. Добавить удобный пользовательский flow привязки/выбора файла для media item.
2. Подготовить playback-options API контракт:
   - выбор озвучки (audio track);
   - выбор качества видео;
   - подключение субтитров.
3. Расширить ручную и автоматическую проверку cross-device continuation.
4. Обновить документы Week 7 (status/acceptance) после каждого stage.

## 5) Важные ограничения

- Не ломать существующие endpoint'ы auth/media/progress/files.
- Работать итерациями:
  - фича -> тесты -> docs.
- На каждом подэтапе поддерживать зеленый тестовый прогон backend.
- Для mobile при недоступном backend ожидать timeout-ошибку (это штатное поведение после фикса Week 6).
- Для инфраструктурных требований ТЗ (24/7, TLS, backup, monitoring) ориентироваться на Week 9 из `docs/week_plan_10_weeks.md`.
