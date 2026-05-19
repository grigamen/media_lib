"""Реэкспорт моделей SQLAlchemy для удобного импорта (одна точка: from app.models import User)."""

from app.models.user import User
from app.models.media_item import MediaItem
from app.models.media_link import MediaLink
from app.models.progress import Progress
from app.models.media_file import MediaFile
from app.models.twofa_email_challenge import TwoFAEmailChallenge
from app.models.user_shelf import UserShelf, UserShelfItem

__all__ = [
    "User",
    "MediaItem",
    "MediaLink",
    "Progress",
    "MediaFile",
    "TwoFAEmailChallenge",
    "UserShelf",
    "UserShelfItem",
]
