# Handoff для следующего агента

Продолжай проект **MediaLib** с текущего состояния после закрытия Week 5.

## 1) Что прочитать в начале

- `docs/week5_status.md` (актуальный статус mobile)
- `docs/week5_acceptance.md` (фактическая приемка Week 5)
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

## 4) Следующая цель по плану: Week 6

Перейти к mobile-блоку **Библиотека, добавление, поиск**:

1. Сделать экран добавления контента и вызов `POST /media-items`.
2. Добавить экран поиска/фильтрации для библиотеки.
3. Показать связи между объектами (`media-links`) в UI.
4. Улучшить обработку пустых/ошибочных состояний.
5. Добавить минимальные widget/integration тесты на ключевые экраны Week 6.

## 5) Важные ограничения

- Не ломать существующие endpoint'ы auth/media/progress/files.
- Работать итерациями:
  - фича -> тесты -> docs.
- На каждом подэтапе поддерживать зеленый тестовый прогон backend.
- Для инфраструктурных требований ТЗ (24/7, TLS, backup, monitoring) ориентироваться на Week 9 из `docs/week_plan_10_weeks.md`.
