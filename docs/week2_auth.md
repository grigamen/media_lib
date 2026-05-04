# Неделя 2: Прогресс по аутентификации backend

## Что реализовано

- Создано backend-окружение (`backend/.venv`) и установлены зависимости.
- Добавлена конфигурация (`backend/.env`, `backend/app/config.py`).
- Реализован слой подключения к БД (`backend/app/db.py`).
- Проверено подключение к PostgreSQL через `GET /health/db`.
- Реализована модель `User` (`backend/app/models/user.py`).
- Инициализирован Alembic и применена первая миграция:
  - `alembic_version`
  - `users`
- Реализовано хеширование/проверка паролей (`backend/app/security.py`).
- Реализованы JWT-утилиты (`backend/app/jwt_utils.py`):
  - access-токен
  - refresh-токен
  - challenge-токен для 2FA
- Реализован Auth API (`backend/app/api/auth.py`):
  - `POST /auth/register`
  - `POST /auth/login`
  - `POST /auth/refresh`
  - `POST /auth/2fa/setup`
  - `POST /auth/2fa/verify`

## Кратко о потоке 2FA

1. Пользователь регистрируется по email и паролю.
2. Пользователь включает 2FA через `/auth/2fa/setup` и получает секрет + OTP URI.
3. Пользователь выполняет вход по email/паролю.
4. Если 2FA включен, backend возвращает `requires_2fa=true` и `challenge_token`.
5. Пользователь отправляет OTP-код в `/auth/2fa/verify` вместе с `challenge_token`.
6. После успешной проверки OTP backend выдает access/refresh токены.

## Тесты

- Добавлен набор тестов: `backend/tests/test_auth.py`
- Реализованы проверки:
  - успешная регистрация и вход
  - вход с неверным паролем возвращает 401
  - refresh возвращает пару токенов
  - успешный сценарий setup + verify для 2FA

### Команда запуска тестов

```bash
cd backend
.\.venv\Scripts\python.exe -m pytest -q
```

### Последний результат

- `4 passed`

## Чеклист ручной проверки

- Запустить backend:
  - `.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --port 8000`
- Открыть Swagger:
  - `http://127.0.0.1:8000/docs`
- Проверить endpoint'ы:
  - регистрация пользователя
  - вход пользователя
  - обновление токена
  - включение 2FA
  - вход с 2FA challenge
  - проверка OTP и получение токенов

## Примечания

- `backend/.env` исключен из VCS.
- `backend/.venv` исключен из VCS.
- `bcrypt` зафиксирован на версии, совместимой с `passlib`.
