"""Shared pytest fixtures."""

from __future__ import annotations

import pytest

from app.config import settings


@pytest.fixture(autouse=True)
def _disable_s3_head_verify_in_tests(monkeypatch: pytest.MonkeyPatch) -> None:
    """Integration tests never PUT bytes to S3 before POST /complete."""
    monkeypatch.setattr(settings, "VERIFY_UPLOAD_OBJECT_IN_STORAGE", False)
