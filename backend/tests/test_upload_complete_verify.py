"""Tests for POST /media-files/{id}/complete storage verification."""

from unittest.mock import MagicMock

from botocore.exceptions import ClientError
from fastapi.testclient import TestClient

from app.config import settings
from app.main import app

from tests.test_media import _register_and_token

client = TestClient(app)


def test_complete_returns_400_when_object_missing_in_storage(monkeypatch) -> None:
    monkeypatch.setattr(settings, "VERIFY_UPLOAD_OBJECT_IN_STORAGE", True)
    mock_s3 = MagicMock()
    mock_s3.head_object.side_effect = ClientError(
        {"Error": {"Code": "404", "Message": "Not Found"}},
        "HeadObject",
    )
    monkeypatch.setattr("app.api.media._build_s3_client_internal", lambda: mock_s3)

    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}
    create = client.post("/media-items", json={"type": "video", "title": "Verify"}, headers=headers)
    assert create.status_code == 201
    media_id = create.json()["id"]
    init = client.post(
        f"/media-items/{media_id}/files/upload",
        json={"filename": "a.mp4", "content_type": "video/mp4", "file_size": 100},
        headers=headers,
    )
    assert init.status_code == 201
    file_id = init.json()["file_id"]

    complete = client.post(f"/media-files/{file_id}/complete", headers=headers)
    assert complete.status_code == 400
    assert "storage" in complete.json()["detail"].lower()


def test_complete_returns_400_when_storage_size_mismatch(monkeypatch) -> None:
    monkeypatch.setattr(settings, "VERIFY_UPLOAD_OBJECT_IN_STORAGE", True)
    mock_s3 = MagicMock()
    mock_s3.head_object.return_value = {"ContentLength": 50}
    monkeypatch.setattr("app.api.media._build_s3_client_internal", lambda: mock_s3)

    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}
    create = client.post("/media-items", json={"type": "video", "title": "Size"}, headers=headers)
    assert create.status_code == 201
    media_id = create.json()["id"]
    init = client.post(
        f"/media-items/{media_id}/files/upload",
        json={"filename": "a.mp4", "content_type": "video/mp4", "file_size": 100},
        headers=headers,
    )
    assert init.status_code == 201
    file_id = init.json()["file_id"]

    complete = client.post(f"/media-files/{file_id}/complete", headers=headers)
    assert complete.status_code == 400
    detail = complete.json()["detail"]
    assert "100" in detail
    assert "50" in detail


def test_complete_succeeds_when_size_matches(monkeypatch) -> None:
    monkeypatch.setattr(settings, "VERIFY_UPLOAD_OBJECT_IN_STORAGE", True)
    mock_s3 = MagicMock()
    mock_s3.head_object.return_value = {"ContentLength": 100}
    monkeypatch.setattr("app.api.media._build_s3_client_internal", lambda: mock_s3)

    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}
    create = client.post("/media-items", json={"type": "video", "title": "Ok"}, headers=headers)
    assert create.status_code == 201
    media_id = create.json()["id"]
    init = client.post(
        f"/media-items/{media_id}/files/upload",
        json={"filename": "a.mp4", "content_type": "video/mp4", "file_size": 100},
        headers=headers,
    )
    assert init.status_code == 201
    file_id = init.json()["file_id"]

    complete = client.post(f"/media-files/{file_id}/complete", headers=headers)
    assert complete.status_code == 200
    assert complete.json()["upload_status"] == "ready"
    mock_s3.head_object.assert_called_once()
