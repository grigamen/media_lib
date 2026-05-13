from __future__ import annotations

import hashlib
import secrets
from uuid import UUID

from app.config import settings


def generate_numeric_otp(*, length: int | None = None) -> str:
    n = length or settings.TWOFA_CODE_LENGTH
    return "".join(secrets.choice("0123456789") for _ in range(n))


def hash_otp_code(code: str, user_id: UUID) -> str:
    pepper = settings.TWOFA_OTP_PEPPER or settings.JWT_SECRET
    raw = f"{code.strip()}:{user_id}:{pepper}".encode()
    return hashlib.sha256(raw).hexdigest()
