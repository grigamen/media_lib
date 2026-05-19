"""Личные полки: только владелец видит и управляет своими полками."""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.api.media import (
    _average_ratings_for_items,
    _get_visible_media_item,
    _media_item_to_response,
)
from app.db import get_db
from app.models import MediaItem, User
from app.models.user_shelf import UserShelf, UserShelfItem
from app.schemas.shelves import (
    ShelfCreate,
    ShelfDetailResponse,
    ShelfItemAddRequest,
    ShelfResponse,
    ShelfUpdate,
)

router = APIRouter(prefix="", tags=["shelves"])


def _get_owned_shelf(db: Session, shelf_id: UUID, current_user: User) -> UserShelf:
    shelf = db.get(UserShelf, shelf_id)
    if shelf is None or shelf.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shelf not found")
    return shelf


def _shelf_cover_url(db: Session, shelf_id: UUID) -> str | None:
    row = db.execute(
        select(MediaItem.cover_url)
        .join(UserShelfItem, UserShelfItem.media_item_id == MediaItem.id)
        .where(
            UserShelfItem.shelf_id == shelf_id,
            MediaItem.cover_url.isnot(None),
            MediaItem.cover_url != "",
        )
        .order_by(UserShelfItem.position.asc(), UserShelfItem.created_at.asc())
        .limit(1)
    ).first()
    if row is None:
        return None
    url = row[0]
    if url is None or not str(url).strip():
        return None
    return str(url).strip()


def _shelf_to_response(db: Session, shelf: UserShelf) -> ShelfResponse:
    count = db.scalar(
        select(func.count()).select_from(UserShelfItem).where(UserShelfItem.shelf_id == shelf.id)
    )
    return ShelfResponse(
        id=shelf.id,
        name=shelf.name,
        item_count=int(count or 0),
        cover_url=_shelf_cover_url(db, shelf.id),
        created_at=shelf.created_at,
        updated_at=shelf.updated_at,
    )


@router.get("/shelves", response_model=list[ShelfResponse])
def list_shelves(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[ShelfResponse]:
    """Список полок текущего пользователя."""
    stmt = (
        select(UserShelf)
        .where(UserShelf.user_id == current_user.id)
        .order_by(UserShelf.updated_at.desc())
    )
    shelves = db.scalars(stmt).all()
    return [_shelf_to_response(db, shelf) for shelf in shelves]


@router.post("/shelves", response_model=ShelfResponse, status_code=status.HTTP_201_CREATED)
def create_shelf(
    payload: ShelfCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ShelfResponse:
    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Name cannot be blank")
    shelf = UserShelf(user_id=current_user.id, name=name)
    db.add(shelf)
    db.commit()
    db.refresh(shelf)
    return _shelf_to_response(db, shelf)


@router.get("/shelves/{shelf_id}", response_model=ShelfDetailResponse)
def get_shelf(
    shelf_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ShelfDetailResponse:
    shelf = _get_owned_shelf(db, shelf_id, current_user)
    stmt = (
        select(UserShelfItem, MediaItem)
        .join(MediaItem, MediaItem.id == UserShelfItem.media_item_id)
        .where(
            UserShelfItem.shelf_id == shelf.id,
            MediaItem.deleted_at.is_(None),
        )
        .order_by(UserShelfItem.position.asc(), UserShelfItem.created_at.asc())
    )
    rows = db.execute(stmt).all()
    item_ids = [media_item.id for _, media_item in rows]
    ratings = _average_ratings_for_items(db, item_ids)
    items = [_media_item_to_response(media_item, ratings) for _, media_item in rows]
    return ShelfDetailResponse(
        id=shelf.id,
        name=shelf.name,
        items=items,
        created_at=shelf.created_at,
        updated_at=shelf.updated_at,
    )


@router.patch("/shelves/{shelf_id}", response_model=ShelfResponse)
def update_shelf(
    shelf_id: UUID,
    payload: ShelfUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ShelfResponse:
    shelf = _get_owned_shelf(db, shelf_id, current_user)
    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Name cannot be blank")
    shelf.name = name
    shelf.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(shelf)
    return _shelf_to_response(db, shelf)


@router.delete("/shelves/{shelf_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_shelf(
    shelf_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    shelf = _get_owned_shelf(db, shelf_id, current_user)
    db.delete(shelf)
    db.commit()


@router.post("/shelves/{shelf_id}/items", response_model=ShelfResponse)
def add_shelf_item(
    shelf_id: UUID,
    payload: ShelfItemAddRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ShelfResponse:
    shelf = _get_owned_shelf(db, shelf_id, current_user)
    _get_visible_media_item(db, payload.media_item_id, current_user)

    max_pos = db.scalar(
        select(func.max(UserShelfItem.position)).where(UserShelfItem.shelf_id == shelf.id)
    )
    next_pos = int(max_pos or 0) + 1

    entry = UserShelfItem(
        shelf_id=shelf.id,
        media_item_id=payload.media_item_id,
        position=next_pos,
    )
    db.add(entry)
    shelf.updated_at = datetime.now(timezone.utc)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This item is already on the shelf",
        ) from None

    db.refresh(shelf)
    return _shelf_to_response(db, shelf)


@router.delete(
    "/shelves/{shelf_id}/items/{media_item_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def remove_shelf_item(
    shelf_id: UUID,
    media_item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    shelf = _get_owned_shelf(db, shelf_id, current_user)
    stmt = select(UserShelfItem).where(
        UserShelfItem.shelf_id == shelf.id,
        UserShelfItem.media_item_id == media_item_id,
    )
    entry = db.scalar(stmt)
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not on shelf")
    db.delete(entry)
    shelf.updated_at = datetime.now(timezone.utc)
    db.commit()
