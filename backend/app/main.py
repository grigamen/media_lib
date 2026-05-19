"""Точка входа HTTP-API: подключаем маршруты «вход и аккаунт» и «медиатека», даём простые проверки «жив ли сервис»."""

from fastapi import FastAPI
from sqlalchemy import text

from app.api import auth_router, media_router, shelves_router
from app.db import SessionLocal

app = FastAPI(title="MediaLib API", version="0.1.0")
app.include_router(auth_router)
app.include_router(media_router)
app.include_router(shelves_router)


@app.get("/health")
def health() -> dict[str, str]:
    """Минимальная проверка: сервер отвечает, процесс жив."""
    return {"status": "ok"}


@app.get("/health/db")
def health_db() -> dict[str, str]:
    """Проверка связи с базой: если запрос не прошёл — в ответе будет status error."""
    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
        return {"status": "ok"}
    except Exception:
        return {"status": "error"}
