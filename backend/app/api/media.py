from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db import get_db
from app.models import MediaItem, MediaLink, User
from app.schemas.media import (
    MediaItemCreate,
    MediaItemsListResponse,
    MediaItemResponse,
    MediaType,
    MediaItemUpdate,
    MediaLinkCreate,
    MediaLinkResponse,
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
