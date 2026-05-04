# Неделя 3: Каталог и связи media

## Что реализовано

- Добавлены модели:
  - `media_items`
  - `media_links`
- Применена миграция Alembic для новых таблиц и индексов.
- Реализованы endpoint'ы:
  - `POST /media-items`
  - `GET /media-items`
  - `GET /media-items/{id}`
  - `PATCH /media-items/{id}`
  - `DELETE /media-items/{id}` (soft delete)
  - `POST /media-links`
  - `GET /media-items/{id}/links`
  - `DELETE /media-links/{id}`

## Фильтрация и выдача списка

- Поддерживаются фильтры:
  - `q`
  - `type`
  - `include_deleted`
- Поддерживается пагинация:
  - `limit`
  - `offset`
- Поддерживается сортировка:
  - `sort_by=updated_at|created_at|title`
  - `order=asc|desc`
- Формат ответа списка:
  - `items`
  - `total`
  - `limit`
  - `offset`

## Валидация и ошибки

- Запрет пустого `title` после trim (`422`).
- Нельзя связать объект сам с собой (`400`).
- Нельзя создать дублирующую связь (`409`).
- Для `relation_type=related` защищено зеркальное дублирование (`A-B` и `B-A`).
- Нельзя создавать связь с удаленными media (`400`).
- Все операции ограничены владельцем данных (проверка по `current_user`).

## Тесты

- Расширен набор `backend/tests/test_media.py`:
  - CRUD media
  - links flow
  - duplicate / mirrored duplicate links
  - pagination
  - blank title validation
  - linking deleted media
  - filter/search/sort
