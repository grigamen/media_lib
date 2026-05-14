"""Карточка произведения в каталоге: тип (книга/аудио/видео), метаданные, модерация, мягкое удаление."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.user import utcnow
from app.db import Base


class MediaItem(Base):
    """Одна запись в библиотеке (один формат произведения). Несколько записей с одним названием и автором — разные форматы."""
    __tablename__ = "media_items"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)

    type: Mapped[str] = mapped_column(String(20), index=True)
    title: Mapped[str] = mapped_column(String(255), index=True)
    author: Mapped[str | None] = mapped_column(String(255), nullable=True)
    cover_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    genres: Mapped[list[str] | None] = mapped_column(JSONB, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
        nullable=False,
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # Статус проверки: ожидает / одобрено / отклонено; новые записи обычных авторов начинаются как «ожидает».
    moderation_status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
