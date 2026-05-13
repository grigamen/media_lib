from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Literal
from uuid import UUID, uuid4

import boto3
from botocore.client import Config
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, bindparam, func, or_, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_admin
from app.config import DEFAULT_ALLOWED_UPLOAD_CONTENT_TYPES, settings
from app.db import get_db
from app.models import MediaFile, MediaItem, MediaLink, Progress, User
from app.schemas.media import (
    MediaFileCompleteResponse,
    MediaFileListItemResponse,
    MediaFileStreamResponse,
    MediaFileUploadInitRequest,
    MediaFileUploadInitResponse,
    GenreListResponse,
    MediaItemCreate,
    MediaItemsListResponse,
    MediaItemResponse,
    MediaItemUpdate,
    MediaLinkCreate,
    MediaLinkResponse,
    MediaType,
    ProgressResponse,
    ProgressUpdateRequest,
    ModerationStatus,
)

router = APIRouter(prefix="", tags=["media"])
logger = logging.getLogger(__name__)
SortBy = Literal["updated_at", "title", "created_at"]
SortOrder = Literal["asc", "desc"]
DEFAULT_GENRES: tuple[str, ...] = (
    "Фэнтези",
    "Фантастика",
    "Детектив",
    "Классика",
    "Роман",
    "Нон-фикшн",
    "Саморазвитие",
    "Бизнес",
    "История",
    "Научпоп",
)


def _normalize_optional_text(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = value.strip()
    return normalized or None


def _normalize_genres(value: list[str] | None) -> list[str] | None:
    if value is None:
        return None
    normalized: list[str] = []
    seen: set[str] = set()
    for raw in value:
        genre = raw.strip()
        if not genre:
            continue
        lowered = genre.lower()
        if lowered in seen:
            continue
        seen.add(lowered)
        normalized.append(genre)
    return normalized or None


def _get_owned_media_item(db: Session, media_item_id: UUID, current_user: User) -> MediaItem:
    item = db.get(MediaItem, media_item_id)
    if item is None or item.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media item not found")
    return item


def _get_media_item_for_soft_delete(
    db: Session,
    media_item_id: UUID,
    current_user: User,
) -> MediaItem:
    item = db.get(MediaItem, media_item_id)
    if item is None or item.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media item not found")
    if current_user.is_admin:
        return item
    if item.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media item not found")
    return item


def _user_can_read_media_item(item: MediaItem, user: User) -> bool:
    if user.is_admin:
        return True
    if item.user_id == user.id:
        return True
    return item.moderation_status == "approved"


def _get_visible_media_item(db: Session, media_item_id: UUID, current_user: User) -> MediaItem:
    item = db.get(MediaItem, media_item_id)
    if item is None or item.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media item not found")
    if not _user_can_read_media_item(item, current_user):
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


def _build_s3_client_internal():
    return boto3.client(
        "s3",
        region_name=settings.S3_REGION,
        endpoint_url=settings.S3_ENDPOINT_URL,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )


def _build_s3_client_presign():
    endpoint = settings.S3_PUBLIC_ENDPOINT_URL or settings.S3_ENDPOINT_URL
    return boto3.client(
        "s3",
        region_name=settings.S3_REGION,
        endpoint_url=endpoint,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )


def _build_s3_host_ops_client():
    endpoint = settings.S3_ENDPOINT_URL
    if endpoint and "10.0.2.2" in endpoint:
        endpoint = endpoint.replace("10.0.2.2", "127.0.0.1")
    return boto3.client(
        "s3",
        region_name=settings.S3_REGION,
        endpoint_url=endpoint,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )


def _csv_to_content_type_allowset(csv: str) -> set[str]:
    return {item.strip().lower() for item in csv.split(",") if item.strip()}


def _normalize_upload_content_type(content_type: str) -> str:
    t = content_type.strip().lower()
    if t == "video/mkv":
        return "video/x-matroska"
    return t


def _allowed_upload_content_types() -> set[str]:
    # Union: env может добавлять типы, но не должен «вырезать» форматы из приложения.
    return _csv_to_content_type_allowset(
        settings.ALLOWED_UPLOAD_CONTENT_TYPES
    ) | _csv_to_content_type_allowset(DEFAULT_ALLOWED_UPLOAD_CONTENT_TYPES)


def _ensure_bucket_exists(s3_client) -> None:
    bucket = settings.S3_BUCKET
    client_for_ops = s3_client
    if settings.S3_ENDPOINT_URL and "10.0.2.2" in settings.S3_ENDPOINT_URL:
        client_for_ops = _build_s3_host_ops_client()
    try:
        client_for_ops.head_bucket(Bucket=bucket)
        return
    except ClientError:
        pass
    except BotoCoreError:
        # In local/dev scenarios storage may be temporarily unavailable.
        # We still return presigned URLs and let upload request reveal the issue.
        return
    try:
        client_for_ops.create_bucket(Bucket=bucket)
    except ClientError as exc:
        error_code = str((exc.response or {}).get("Error", {}).get("Code", ""))
        if error_code in {"BucketAlreadyOwnedByYou", "BucketAlreadyExists"}:
            return
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="S3 bucket is unavailable for upload",
        ) from exc
    except BotoCoreError:
        return


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
        cover_url=_normalize_optional_text(payload.cover_url),
        genres=_normalize_genres(payload.genres),
        description=_normalize_optional_text(payload.description),
        metadata_json=payload.metadata_json,
        moderation_status="pending",
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.get("/media-items", response_model=MediaItemsListResponse)
def list_media_items(
    q: str | None = Query(default=None, min_length=1, max_length=255),
    type: MediaType | None = Query(default=None),
    types: list[MediaType] | None = Query(default=None),
    genres: list[str] | None = Query(default=None),
    include_deleted: bool = Query(default=False),
    moderation_status: ModerationStatus | None = Query(default=None),
    exclude_pending: bool = Query(default=False),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    sort_by: SortBy = Query(default="updated_at"),
    order: SortOrder = Query(default="desc"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MediaItemsListResponse:
    conditions = []
    if not include_deleted:
        conditions.append(MediaItem.deleted_at.is_(None))
    if moderation_status is not None:
        if not current_user.is_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Moderation filter is admin-only",
            )
        conditions.append(MediaItem.moderation_status == moderation_status)
    elif exclude_pending:
        if not current_user.is_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="exclude_pending is admin-only",
            )
        conditions.append(MediaItem.moderation_status != "pending")
    if not current_user.is_admin:
        conditions.append(
            or_(
                MediaItem.moderation_status == "approved",
                MediaItem.user_id == current_user.id,
            )
        )
    elif moderation_status is None:
        # Default library list for admins: hide other users' rejected works (they
        # still appear under moderation filters). Own rejected items stay listed.
        conditions.append(
            or_(
                MediaItem.moderation_status != "rejected",
                MediaItem.user_id == current_user.id,
            )
        )
    effective_types: list[str] = []
    if types:
        effective_types = list(types)
    elif type is not None:
        effective_types = [type]
    if effective_types:
        conditions.append(MediaItem.type.in_(tuple(effective_types)))
    if q:
        conditions.append(
            or_(
                MediaItem.title.ilike(f"%{q}%"),
                MediaItem.author.ilike(f"%{q}%"),
            )
        )
    genre_terms: list[str] = []
    if genres:
        seen_g: set[str] = set()
        for raw in genres[:24]:
            g = (raw or "").strip().lower()
            if not g or g in seen_g:
                continue
            seen_g.add(g)
            genre_terms.append(g[:120])
    if genre_terms:
        conditions.append(
            text(
                "EXISTS (SELECT 1 FROM jsonb_array_elements_text("
                "COALESCE(media_items.genres, '[]'::jsonb)) AS _genre_el "
                "WHERE lower(trim(_genre_el::text)) IN :gf)"
            ).bindparams(bindparam("gf", expanding=True, value=genre_terms))
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


@router.get("/media-genres", response_model=GenreListResponse)
def list_media_genres(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> GenreListResponse:
    query = text(
        """
        SELECT DISTINCT trim(genre_value) AS genre
        FROM media_items
        CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(genres, '[]'::jsonb)) AS genre_value
        WHERE deleted_at IS NULL
          AND moderation_status = 'approved'
          AND trim(genre_value) <> ''
        ORDER BY trim(genre_value) ASC
        """
    )
    rows = db.execute(query).all()
    existing = [str(row[0]) for row in rows if row and row[0]]
    merged: list[str] = []
    seen: set[str] = set()
    for genre in [*existing, *DEFAULT_GENRES]:
        key = genre.strip().lower()
        if not key or key in seen:
            continue
        seen.add(key)
        merged.append(genre.strip())
    return GenreListResponse(genres=merged)


@router.get("/media-items/{media_item_id}", response_model=MediaItemResponse)
def get_media_item(
    media_item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MediaItem:
    return _get_visible_media_item(db, media_item_id, current_user)


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
    if "cover_url" in updates:
        updates["cover_url"] = _normalize_optional_text(updates["cover_url"])
    if "genres" in updates:
        updates["genres"] = _normalize_genres(updates["genres"])
    if "description" in updates:
        updates["description"] = _normalize_optional_text(updates["description"])

    for field, value in updates.items():
        setattr(item, field, value)

    if item.moderation_status == "rejected" and updates:
        item.moderation_status = "pending"

    db.commit()
    db.refresh(item)
    return item


@router.delete("/media-items/{media_item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_media_item(
    media_item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    item = _get_media_item_for_soft_delete(db, media_item_id, current_user)

    item.deleted_at = datetime.now(timezone.utc)
    db.commit()


@router.get("/media-items/{media_item_id}/progress", response_model=ProgressResponse)
def get_media_progress(
    media_item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Progress:
    _get_visible_media_item(db, media_item_id, current_user)

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
    _get_visible_media_item(db, media_item_id, current_user)

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

    content_type = _normalize_upload_content_type(payload.content_type)
    if not content_type:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Content type cannot be blank")

    allowed_types = _allowed_upload_content_types()
    if content_type not in allowed_types:
        # Временно: смотреть в консоли uvicorn / docker logs при 400.
        logger.warning(
            "upload rejected unsupported content_type: raw=%r normalized=%r filename=%r",
            payload.content_type,
            content_type,
            payload.filename,
        )
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

    s3_internal = _build_s3_client_internal()
    _ensure_bucket_exists(s3_internal)
    s3_presign = _build_s3_client_presign()
    upload_url = s3_presign.generate_presigned_url(
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


@router.get("/media-items/{media_item_id}/files", response_model=list[MediaFileListItemResponse])
def list_media_item_files(
    media_item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[MediaFile]:
    _get_visible_media_item(db, media_item_id, current_user)
    stmt = (
        select(MediaFile)
        .where(MediaFile.media_item_id == media_item_id)
        .order_by(MediaFile.created_at.desc())
    )
    return list(db.scalars(stmt).all())


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
    if media_file is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media file not found")
    media_item = db.get(MediaItem, media_file.media_item_id)
    if media_item is None or media_item.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media item not found")
    if not _user_can_read_media_item(media_item, current_user):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media item not found")
    if media_file.upload_status != "ready":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="File upload is not completed")

    s3_internal = _build_s3_client_internal()
    _ensure_bucket_exists(s3_internal)
    s3_presign = _build_s3_client_presign()
    stream_url = s3_presign.generate_presigned_url(
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
    _get_visible_media_item(db, media_item_id, current_user)

    stmt = select(MediaLink).where(
        or_(
            MediaLink.source_media_id == media_item_id,
            MediaLink.target_media_id == media_item_id,
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


@router.post(
    "/admin/media-items/{media_item_id}/approve",
    response_model=MediaItemResponse,
)
def admin_approve_media_item(
    media_item_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
) -> MediaItem:
    item = db.get(MediaItem, media_item_id)
    if item is None or item.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media item not found")
    item.moderation_status = "approved"
    db.commit()
    db.refresh(item)
    return item


@router.post(
    "/admin/media-items/{media_item_id}/reject",
    response_model=MediaItemResponse,
)
def admin_reject_media_item(
    media_item_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
) -> MediaItem:
    item = db.get(MediaItem, media_item_id)
    if item is None or item.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media item not found")
    item.moderation_status = "rejected"
    db.commit()
    db.refresh(item)
    return item
