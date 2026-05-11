"""
Utility: soft-delete media_items rows (sets deleted_at), bypassing HTTP ownership checks.

Run from the backend directory:
  python scripts/soft_delete_media_items.py --list
  python scripts/soft_delete_media_items.py --dry-run --except-user-id <uuid>
  python scripts/soft_delete_media_items.py --except-user-id <uuid>

Requires DATABASE_URL in .env (same as the API).
"""
from __future__ import annotations

import argparse
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import SessionLocal
from app.models.media_item import MediaItem
from app.models.user import User


def _list_owners(db: Session) -> None:
    q = (
        select(User.id, User.email, User.display_name, func.count(MediaItem.id))
        .join(MediaItem, MediaItem.user_id == User.id)
        .where(MediaItem.deleted_at.is_(None))
        .group_by(User.id, User.email, User.display_name)
        .order_by(User.email)
    )
    rows = db.execute(q).all()
    if not rows:
        print("No active (non-deleted) media_items.")
        return
    print("Active media_items by owner:")
    for uid, email, name, cnt in rows:
        print(f"  {cnt:4d}  {email}  ({name})  user_id={uid}")


def main() -> None:
    p = argparse.ArgumentParser(description="Soft-delete media_items in Postgres.")
    p.add_argument(
        "--list",
        action="store_true",
        help="List users and counts of active media items they own.",
    )
    p.add_argument(
        "--except-user-id",
        type=uuid.UUID,
        metavar="UUID",
        help="Soft-delete all active items whose user_id is NOT this (keep this user's library).",
    )
    p.add_argument(
        "--only-user-id",
        type=uuid.UUID,
        metavar="UUID",
        help="Soft-delete all active items owned by this user only.",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Show how many rows would be updated; do not commit.",
    )
    args = p.parse_args()
    if not args.list and args.except_user_id is None and args.only_user_id is None:
        p.print_help()
        raise SystemExit(1)
    if args.except_user_id is not None and args.only_user_id is not None:
        print("Use only one of --except-user-id / --only-user-id.", file=sys.stderr)
        raise SystemExit(2)

    now = datetime.now(timezone.utc)
    db = SessionLocal()
    try:
        if args.list:
            _list_owners(db)
        if args.only_user_id is not None:
            q = select(MediaItem).where(
                MediaItem.user_id == args.only_user_id,
                MediaItem.deleted_at.is_(None),
            )
            items = list(db.scalars(q).all())
            print(f"{'Would soft-delete' if args.dry_run else 'Soft-deleting'} {len(items)} item(s) for user_id={args.only_user_id}")
            if not args.dry_run:
                for item in items:
                    item.deleted_at = now
                db.commit()
            else:
                db.rollback()
        if args.except_user_id is not None:
            q = select(MediaItem).where(
                MediaItem.user_id != args.except_user_id,
                MediaItem.deleted_at.is_(None),
            )
            items = list(db.scalars(q).all())
            print(
                f"{'Would soft-delete' if args.dry_run else 'Soft-deleting'} {len(items)} item(s) "
                f"(all owners except user_id={args.except_user_id})"
            )
            if not args.dry_run:
                for item in items:
                    item.deleted_at = now
                db.commit()
            else:
                db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    main()
