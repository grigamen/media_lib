"""Подключение к базе данных: один общий «движок», фабрика сессий и генератор сессии для каждого HTTP-запроса."""

from typing import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import settings


engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    """Базовый класс для всех таблиц SQLAlchemy в этом проекте."""


def get_db() -> Generator[Session, None, None]:
    """Открывает сессию на время одного запроса и гарантированно закрывает её в конце."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
