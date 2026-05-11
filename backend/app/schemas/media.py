from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

MediaType = Literal["book", "audiobook", "video"]
RelationType = Literal["audioversion", "adaptation", "related"]
UploadStatus = Literal["pending", "ready"]
ModerationStatus = Literal["pending", "approved", "rejected"]


class MediaItemCreate(BaseModel):
    type: MediaType
    title: str = Field(min_length=1, max_length=255)
    author: str | None = Field(default=None, max_length=255)
    cover_url: str | None = Field(default=None, max_length=1024)
    genres: list[str] | None = None
    description: str | None = None
    metadata_json: dict | None = None


class MediaItemUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    author: str | None = Field(default=None, max_length=255)
    cover_url: str | None = Field(default=None, max_length=1024)
    genres: list[str] | None = None
    description: str | None = None
    metadata_json: dict | None = None


class MediaItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    type: MediaType
    title: str
    author: str | None = None
    cover_url: str | None = None
    genres: list[str] | None = None
    description: str | None = None
    metadata_json: dict | None = None
    moderation_status: ModerationStatus
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None


class MediaItemsListResponse(BaseModel):
    items: list[MediaItemResponse]
    total: int
    limit: int
    offset: int


class GenreListResponse(BaseModel):
    genres: list[str]


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


class ProgressUpdateRequest(BaseModel):
    position_seconds: int = Field(ge=0)
    duration_seconds: int | None = Field(default=None, ge=1)
    is_completed: bool = False


class ProgressResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    media_item_id: UUID
    position_seconds: int
    duration_seconds: int | None = None
    progress_percent: float
    is_completed: bool
    created_at: datetime
    updated_at: datetime


class MediaFileUploadInitRequest(BaseModel):
    filename: str = Field(min_length=1, max_length=255)
    content_type: str = Field(min_length=1, max_length=255)
    file_size: int = Field(ge=1)


class MediaFileUploadInitResponse(BaseModel):
    file_id: UUID
    media_item_id: UUID
    upload_status: UploadStatus
    storage_key: str
    upload_url: str
    expires_in_sec: int
    method: str = "PUT"


class MediaFileCompleteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    media_item_id: UUID
    upload_status: UploadStatus
    uploaded_at: datetime | None = None


class MediaFileStreamResponse(BaseModel):
    file_id: UUID
    media_item_id: UUID
    stream_url: str
    expires_in_sec: int


class MediaFileListItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    content_type: str
    file_size: int | None = None
    upload_status: UploadStatus
    uploaded_at: datetime | None = None
    created_at: datetime
