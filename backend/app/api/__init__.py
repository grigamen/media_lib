"""Собираем маршруты из подпакетов: вход, регистрация, медиатека — чтобы main.py подключал один раз."""

from app.api.auth import router as auth_router
from app.api.media import router as media_router
from app.api.shelves import router as shelves_router

__all__ = ["auth_router", "media_router", "shelves_router"]
