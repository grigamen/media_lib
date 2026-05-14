"""Таблица пользователей: почта, хэш пароля, имя, флаг администратора и настройки двухфакторной защиты."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


def utcnow() -> datetime:
    """Текущий момент в часовом поясе UTC — так даты в базе не путаются при смене летнего времени."""
    return datetime.now(timezone.utc)


class User(Base):
    """Пользователь приложения: вход по почте, отображаемое имя, может быть админом и включить 2FA."""
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(120))

    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    twofa_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    twofa_secret: Mapped[str | None] = mapped_column(String(64), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
        nullable=False,
    )
