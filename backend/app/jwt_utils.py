"""Выпуск и разбор JWT-токенов: короткий «пропуск» в API и долгий токен для обновления сессии."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from jose import JWTError, jwt

from app.config import settings


def _build_token(
    user_id: str,
    token_type: str,
    expires_delta: timedelta,
    *,
    is_admin: bool | None = None,
) -> str:
    """Собирает подписанный токен: внутри id пользователя, тип и срок действия."""
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": user_id,
        "type": token_type,
        "iat": int(now.timestamp()),
        "exp": int((now + expires_delta).timestamp()),
    }
    if token_type == "access":
        payload["adm"] = bool(is_admin)
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALG)


def create_access_token(user_id: str, *, is_admin: bool = False) -> str:
    """Короткий токен, которым клиент подписывает обычные запросы к API (срок — из настроек ACCESS_TOKEN_MIN)."""
    return _build_token(
        user_id,
        "access",
        timedelta(minutes=settings.ACCESS_TOKEN_MIN),
        is_admin=is_admin,
    )


def create_refresh_token(user_id: str) -> str:
    """Длинный токен только для выдачи новой пары access+refresh, без доступа к данным сам по себе."""
    return _build_token(user_id, "refresh", timedelta(days=settings.REFRESH_TOKEN_DAYS))


def create_twofa_challenge_token(user_id: str) -> str:
    """Временный токен между вводом пароля и вводом кода из письма (двухфакторный вход)."""
    return _build_token(user_id, "twofa_challenge", timedelta(minutes=settings.TWOFA_CHALLENGE_MIN))


def decode_token(token: str) -> dict[str, Any]:
    """Проверяет подпись и срок и возвращает содержимое токена; при ошибке бросает ValueError."""
    try:
        return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALG])
    except JWTError as exc:
        raise ValueError("Invalid token") from exc
