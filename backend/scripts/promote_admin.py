"""Set is_admin=true for a user by email (one-off maintenance)."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import select

from app.db import SessionLocal
from app.models.user import User


def main() -> None:
    p = argparse.ArgumentParser(description="Promote user to admin (is_admin=true).")
    p.add_argument("email", help="User email (lowercase)")
    args = p.parse_args()
    email = args.email.strip().lower()
    db = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.email == email))
        if user is None:
            print(f"No user with email {email}", file=sys.stderr)
            raise SystemExit(1)
        user.is_admin = True
        db.commit()
        print(f"OK: {email} is now admin. Re-login to get a token with admin rights.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
