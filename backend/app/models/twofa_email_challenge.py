"""Модель проверочных кодов из email при двухфакторной защите (сама таблица в базе)."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base
from app.models.user import utcnow


class TwoFAEmailChallenge(Base):
    """Запись в базе для входа или смены 2FA по коду из почты: хранится только хэш кода и срок действия."""

    __tablename__ = "twofa_email_challenges"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    #: Назначение: вход (login), включение или выключение 2FA (enable / disable) — одна строка на попытку.
    purpose: Mapped[str] = mapped_column(String(32), nullable=False, index=True)

    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)

    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    last_sent_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utcnow)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utcnow)
