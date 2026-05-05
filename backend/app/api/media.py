from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal
from uuid import UUID, uuid4

import boto3
from botocore.client import Config
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.config import settings
from app.db import get_db
from app.models import MediaFile, MediaItem, MediaLink, Progress, User
from app.schemas.media import (
    MediaFileCompleteResponse,
    MediaFileStreamResponse,
    MediaFileUploadInitRequest,
    MediaFileUploadInitResponse,
    MediaItemCreate,
    MediaItemsListResponse,
    MediaItemResponse,
    MediaItemUpdate,
    MediaLinkCreate,
    MediaLinkResponse,
    MediaType,
    ProgressResponse,
    ProgressUpdateRequest,
)

router = APIRouter(prefix="", tags=["media"])
SortBy = Literal["updated_at", "title", "created_at"]
SortOrder = Literal["asc", "desc"]


def _normalize_optional_text(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = value.strip()
    return normalized or None


def _get_owned_media_item(db: Session, media_item_id: UUID, current_user: User) -> MediaItem:
    item = db.get(MediaItem, media_item_id)
    if item is None or item.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media item not found")
    return item


def _calculate_progress_percent(position_seconds: int, duration_seconds: int | None) -> float:
    if duration_seconds is None or duration_seconds <= 0:
        return 0.0
    percent = (position_seconds / duration_seconds) * 100
    percent = max(0.0, min(100.0, percent))
    return round(percent, 2)


def _normalize_filename(filename: str) -> str:
    cleaned = filename.strip()
    if not cleaned:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Filename cannot be blank")
    return cleaned.replace("\\", "_").replace("/", "_").replace(" ", "_")


def _build_storage_key(current_user: User, media_item_id: UUID, filename: str) -> str:
    safe_filename = _normalize_filename(filename)
    return f"{current_user.id}/{media_item_id}/{uuid4().hex}_{safe_filename}"


def _build_s3_client():
    return boto3.client(
        "s3",
        region_name=settings.S3_REGION,
        endpoint_url=settings.S3_ENDPOINT_URL,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4"),
    )


def _allowed_upload_content_types() -> set[str]:
    return {item.strip() for item in settings.ALLOWED_UPLOAD_CONTENT_TYPES.split(",") if item.strip()}


@router.post("/media-items", response_model=MediaItemResponse, status_code=status.HTTP_201_CREATED)
def create_media_item(
    payload: MediaItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MediaItem:
    title = payload.title.strip()
    if not title:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Title cannot be blank")

    item = MediaItem(
        user_id=current_user.id,
        type=payload.type,
        title=title,
        author=_normalize_optional_text(payload.author),
        description=_normalize_optional_text(payload.description),
        metadata_json=payload.metadata_json,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.get("/media-items", response_model=MediaItemsListResponse)
def list_media_items(
    q: str | None = Query(default=None, min_length=1, max_length=255),
    type: MediaType | None = Query(default=None),
    include_deleted: bool = Query(default=False),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    sort_by: SortBy = Query(default="updated_at"),
    order: SortOrder = Query(default="desc"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MediaItemsListResponse:
    conditions = [MediaItem.user_id == current_user.id]
    if not include_deleted:
        conditions.append(MediaItem.deleted_at.is_(None))
    if type:
        conditions.append(MediaItem.type == type)
    if q:
        conditions.append(
            or_(
                MediaItem.title.ilike(f"%{q}%"),
                MediaItem.author.ilike(f"%{q}%"),
            )
        )

    where_clause = and_(*conditions)
    total_stmt = select(func.count(MediaItem.id)).where(where_clause)
    total = int(db.scalar(total_stmt) or 0)

    sort_column_map = {
        "updated_at": MediaItem.updated_at,
        "created_at": MediaItem.created_at,
        "title": MediaItem.title,
    }
    sort_column = sort_column_map[sort_by]
    sort_expr = sort_column.asc() if order == "asc" else sort_column.desc()

    stmt = select(MediaItem).where(where_clause).order_by(sort_expr).offset(offset).limit(limit)
    items = list(db.scalars(stmt).all())
    return MediaItemsListResponse(items=items, total=total, limit=limit, offset=offset)


@router.get("/media-items/{media_item_id}", response_model=MediaItemResponse)
def get_media_item(
    media_item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MediaItem:
    item = _get_owned_media_item(db, media_item_id, current_user)
    return item


@router.patch("/media-items/{media_item_id}", response_model=MediaItemResponse)
def update_media_item(
    media_item_id: UUID,
    payload: MediaItemUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MediaItem:
    item = _get_owned_media_item(db, media_item_id, current_user)

    updates = payload.model_dump(exclude_unset=True)
    if "title" in updates and updates["title"] is not None:
        title = updates["title"].strip()
        if not title:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Title cannot be blank")
        updates["title"] = title
    if "author" in updates:
        updates["author"] = _normalize_optional_text(updates["author"])
    if "description" in updates:
        updates["description"] = _normalize_optional_text(updates["description"])

    for field, value in updates.items():
        setattr(item, field, value)

    db.commit()
    db.refresh(item)
    return item


@router.delete("/media-items/{media_item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_media_item(
    media_item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    item = _get_owned_media_item(db, media_item_id, current_user)

    item.deleted_at = datetime.now(timezone.utc)
    db.commit()


@router.get("/media-items/{media_item_id}/progress", response_model=ProgressResponse)
def get_media_progress(
    media_item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Progress:
    _get_owned_media_item(db, media_item_id, current_user)

    stmt = select(Progress).where(
        and_(Progress.user_id == current_user.id, Progress.media_item_id == media_item_id)
    )
    progress = db.scalar(stmt)
    if progress is None:
        progress = Progress(
            user_id=current_user.id,
            media_item_id=media_item_id,
            position_seconds=0,
            duration_seconds=None,
            progress_percent=0,
            is_completed=False,
        )
        db.add(progress)
        db.commit()
        db.refresh(progress)
    return progress


@router.put("/media-items/{media_item_id}/progress", response_model=ProgressResponse)
def upsert_media_progress(
    media_item_id: UUID,
    payload: ProgressUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Progress:
    _get_owned_media_item(db, media_item_id, current_user)

    stmt = select(Progress).where(
        and_(Progress.user_id == current_user.id, Progress.media_item_id == media_item_id)
    )
    progress = db.scalar(stmt)
    if progress is None:
        progress = Progress(
            user_id=current_user.id,
            media_item_id=media_item_id,
        )
        db.add(progress)

    position_seconds = payload.position_seconds
    duration_seconds = payload.duration_seconds
    if duration_seconds is not None:
        position_seconds = min(position_seconds, duration_seconds)
    elif progress.duration_seconds is not None:
        position_seconds = min(position_seconds, progress.duration_seconds)
        duration_seconds = progress.duration_seconds

    progress.position_seconds = position_seconds
    progress.duration_seconds = duration_seconds
    progress.is_completed = payload.is_completed or (
        duration_seconds is not None and position_seconds >= duration_seconds
    )
    progress.progress_percent = _calculate_progress_percent(position_seconds, duration_seconds)

    db.commit()
    db.refresh(progress)
    return progress


@router.post(
    "/media-items/{media_item_id}/files/upload",
    response_model=MediaFileUploadInitResponse,
    status_code=status.HTTP_201_CREATED,
)
def initiate_file_upload(
    media_item_id: UUID,
    payload: MediaFileUploadInitRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MediaFileUploadInitResponse:
    media_item = _get_owned_media_item(db, media_item_id, current_user)
    if media_item.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot upload for deleted media item")

    content_type = payload.content_type.strip().lower()
    if not content_type:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Content type cannot be blank")

    allowed_types = _allowed_upload_content_types()
    if content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported content type",
        )
    if payload.file_size > settings.MAX_UPLOAD_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File size exceeds allowed limit",
        )

    storage_key = _build_storage_key(current_user, media_item_id, payload.filename)
    media_file = MediaFile(
        user_id=current_user.id,
        media_item_id=media_item_id,
        storage_provider="s3",
        storage_bucket=settings.S3_BUCKET,
        storage_key=storage_key,
        content_type=content_type,
        file_size=payload.file_size,
        upload_status="pending",
    )
    db.add(media_file)
    db.commit()
    db.refresh(media_file)

    s3_client = _build_s3_client()
    upload_url = s3_client.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket": settings.S3_BUCKET,
            "Key": storage_key,
            "ContentType": media_file.content_type,
        },
        ExpiresIn=settings.S3_PRESIGNED_EXPIRES_SEC,
        HttpMethod="PUT",
    )
    return MediaFileUploadInitResponse(
        file_id=media_file.id,
        media_item_id=media_file.media_item_id,
        upload_status=media_file.upload_status,
        storage_key=storage_key,
        upload_url=upload_url,
        expires_in_sec=settings.S3_PRESIGNED_EXPIRES_SEC,
    )


@router.post("/media-files/{file_id}/complete", response_model=MediaFileCompleteResponse)
def complete_file_upload(
    file_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MediaFile:
    media_file = db.get(MediaFile, file_id)
    if media_file is None or media_file.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media file not found")
    if media_file.upload_status == "ready":
        return media_file

    media_file.upload_status = "ready"
    media_file.uploaded_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(media_file)
    return media_file


@router.get("/media-files/{file_id}/stream", response_model=MediaFileStreamResponse)
def get_stream_url(
    file_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MediaFileStreamResponse:
    media_file = db.get(MediaFile, file_id)
    if media_file is None or media_file.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media file not found")
    if media_file.upload_status != "ready":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="File upload is not completed")

    s3_client = _build_s3_client()
    stream_url = s3_client.generate_presigned_url(
        ClientMethod="get_object",
        Params={
            "Bucket": media_file.storage_bucket,
            "Key": media_file.storage_key,
        },
        ExpiresIn=settings.S3_PRESIGNED_EXPIRES_SEC,
        HttpMethod="GET",
    )
    return MediaFileStreamResponse(
        file_id=media_file.id,
        media_item_id=media_file.media_item_id,
        stream_url=stream_url,
        expires_in_sec=settings.S3_PRESIGNED_EXPIRES_SEC,
    )


@router.post("/media-links", response_model=MediaLinkResponse, status_code=status.HTTP_201_CREATED)
def create_media_link(
    payload: MediaLinkCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MediaLink:
    if payload.source_media_id == payload.target_media_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Source and target must differ")

    source_media_id = payload.source_media_id
    target_media_id = payload.target_media_id
    if payload.relation_type == "related":
        # Normalize pair order for undirected relation to avoid mirrored duplicates.
        if source_media_id.int > target_media_id.int:
            source_media_id, target_media_id = target_media_id, source_media_id

    source = _get_owned_media_item(db, source_media_id, current_user)
    target = _get_owned_media_item(db, target_media_id, current_user)
    if source.deleted_at is not None or target.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot link deleted media items")

    link = MediaLink(
        user_id=current_user.id,
        source_media_id=source_media_id,
        target_media_id=target_media_id,
        relation_type=payload.relation_type,
    )
    db.add(link)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Media link already exists or is invalid",
        ) from exc
    db.refresh(link)
    return link


@router.get("/media-items/{media_item_id}/links", response_model=list[MediaLinkResponse])
def list_media_links(
    media_item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[MediaLink]:
    _get_owned_media_item(db, media_item_id, current_user)

    stmt = select(MediaLink).where(
        and_(
            MediaLink.user_id == current_user.id,
            or_(
                MediaLink.source_media_id == media_item_id,
                MediaLink.target_media_id == media_item_id,
            ),
        )
    )
    return list(db.scalars(stmt).all())


@router.delete("/media-links/{link_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_media_link(
    link_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    link = db.get(MediaLink, link_id)
    if link is None or link.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media link not found")

    db.delete(link)
    db.commit()
