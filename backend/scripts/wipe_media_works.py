"""
Удалить из Postgres только произведения и всё, что от них зависит:
media_items, media_links, media_files, progress.
Таблица users не изменяется (аккаунты остаются).

Запуск из каталога backend/:
  python scripts/wipe_media_works.py --yes
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

_TABLES = (
    "media_links",
    "media_files",
    "progress",
    "media_items",
)


def main() -> None:
    p = argparse.ArgumentParser(
        description="Truncate media-related tables only (keeps users).",
    )
    p.add_argument(
        "--yes",
        action="store_true",
        help="Обязательно: подтверждение удаления данных произведений.",
    )
    args = p.parse_args()
    if not args.yes:
        print("Нужен флаг --yes.", file=sys.stderr)
        raise SystemExit(1)

    sql = "TRUNCATE TABLE " + ", ".join(_TABLES) + " RESTART IDENTITY CASCADE;"
    engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    with engine.begin() as conn:
        conn.execute(text(sql))
    print("OK: очищены таблицы:", ", ".join(_TABLES))


if __name__ == "__main__":
    main()
