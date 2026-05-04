from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

MediaType = Literal["book", "audiobook", "video"]
RelationType = Literal["audioversion", "adaptation", "related"]


class MediaItemCreate(BaseModel):
    type: MediaType
    title: str = Field(min_length=1, max_length=255)
    author: str | None = Field(default=None, max_length=255)
    description: str | None = None
    metadata_json: dict | None = None


class MediaItemUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    author: str | None = Field(default=None, max_length=255)
    description: str | None = None
    metadata_json: dict | None = None


class MediaItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    type: MediaType
    title: str
    author: str | None = None
    description: str | None = None
    metadata_json: dict | None = None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None


class MediaItemsListResponse(BaseModel):
    items: list[MediaItemResponse]
    total: int
    limit: int
    offset: int


class MediaLinkCreate(BaseModel):
    source_media_id: UUID
    target_media_id: UUID
    relation_type: RelationType


class MediaLinkResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    source_media_id: UUID
    target_media_id: UUID
    relation_type: RelationType
    created_at: datetime
