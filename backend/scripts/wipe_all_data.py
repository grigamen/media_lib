"""
Remove all application data from Postgres (users, media, progress, files, links).
Schema and alembic_version are kept.
To clear only works/media and keep user accounts, use wipe_media_works.py instead.

From backend/:
  python scripts/wipe_all_data.py --yes
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import create_engine, text

from app.config import settings

# Order: children first; CASCADE handles the rest if the engine supports it.
_TABLES = (
    "media_links",
    "media_files",
    "progress",
    "media_items",
    "users",
)


def main() -> None:
    p = argparse.ArgumentParser(description="Truncate all application tables (data only).")
    p.add_argument(
        "--yes",
        action="store_true",
        help="Required. Confirms you want to delete all rows.",
    )
    args = p.parse_args()
    if not args.yes:
        print("Refusing to run without --yes.", file=sys.stderr)
        raise SystemExit(1)

    sql = (
        "TRUNCATE TABLE "
        + ", ".join(_TABLES)
        + " RESTART IDENTITY CASCADE;"
    )
    engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    with engine.begin() as conn:
        conn.execute(text(sql))
    print("OK: truncated", ", ".join(_TABLES))


if __name__ == "__main__":
    main()
