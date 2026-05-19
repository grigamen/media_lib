"""Схемы API личных полок."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.media import MediaItemResponse


class ShelfCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)


class ShelfUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=120)


class ShelfResponse(BaseModel):
    id: UUID
    name: str
    item_count: int = 0
    created_at: datetime
    updated_at: datetime


class ShelfDetailResponse(BaseModel):
    id: UUID
    name: str
    items: list[MediaItemResponse]
    created_at: datetime
    updated_at: datetime


class ShelfItemAddRequest(BaseModel):
    media_item_id: UUID
