# Week 5 Status (mobile: auth + базовый UI)

## Что сделано

- Сформирована базовая mobile-архитектура по feature-модулям:
  - `lib/app`
  - `lib/core`
  - `lib/features/auth`
  - `lib/features/library`
  - `lib/features/profile`
- Реализован конфиг API (`API_BASE_URL`) через dart-define:
  - `lib/core/config/app_config.dart`
- Добавлен HTTP-клиент и обработка API-ошибок:
  - `lib/core/network/api_client.dart`
- Реализован auth flow:
  - регистрация и логин через backend auth API
  - auth-screen с валидацией и состояниями загрузки/ошибок
- Реализован экран библиотеки:
  - загрузка каталога через `GET /media-items`
  - pull-to-refresh
  - пустые/ошибочные состояния
- Реализован экран профиля:
  - отображение email пользователя
  - выход из сессии
  - переключение светлой/темной темы
- Реализован роутинг на уровне app-shell:
  - auth route для неавторизованных
  - home shell (library/profile) для авторизованных

## Текущее качество

- `flutter analyze`: без ошибок.
- `flutter test`: тесты проходят.

## Следующие шаги (Week 6)

- Экран добавления контента.
- Экран поиска и фильтрации.
- Отображение связей между объектами.
- Дополнительные widget/integration тесты ключевых сценариев.
