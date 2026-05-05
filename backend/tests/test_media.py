from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _register_and_token() -> str:
    email = f"media_{uuid4().hex[:8]}@test.com"
    password = "Test123!"
    register_res = client.post(
        "/auth/register",
        json={"email": email, "password": password, "display_name": "Media Tester"},
    )
    assert register_res.status_code == 201

    login_res = client.post("/auth/login", json={"email": email, "password": password})
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]
    assert token
    return token


def test_media_item_crud_flow() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    create_res = client.post(
        "/media-items",
        json={"type": "book", "title": "Dune", "author": "Frank Herbert"},
        headers=headers,
    )
    assert create_res.status_code == 201
    item = create_res.json()
    media_id = item["id"]

    list_res = client.get("/media-items", headers=headers)
    assert list_res.status_code == 200
    list_data = list_res.json()
    assert list_data["total"] >= 1
    assert any(entry["id"] == media_id for entry in list_data["items"])

    patch_res = client.patch(
        f"/media-items/{media_id}",
        json={"title": "Dune Updated"},
        headers=headers,
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["title"] == "Dune Updated"

    delete_res = client.delete(f"/media-items/{media_id}", headers=headers)
    assert delete_res.status_code == 204


def test_media_links_flow() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    source_res = client.post(
        "/media-items",
        json={"type": "book", "title": "Book A"},
        headers=headers,
    )
    target_res = client.post(
        "/media-items",
        json={"type": "audiobook", "title": "Audio A"},
        headers=headers,
    )
    assert source_res.status_code == 201
    assert target_res.status_code == 201

    source_id = source_res.json()["id"]
    target_id = target_res.json()["id"]

    create_link_res = client.post(
        "/media-links",
        json={
            "source_media_id": source_id,
            "target_media_id": target_id,
            "relation_type": "audioversion",
        },
        headers=headers,
    )
    assert create_link_res.status_code == 201
    link_id = create_link_res.json()["id"]

    list_links_res = client.get(f"/media-items/{source_id}/links", headers=headers)
    assert list_links_res.status_code == 200
    assert any(link["id"] == link_id for link in list_links_res.json())

    delete_link_res = client.delete(f"/media-links/{link_id}", headers=headers)
    assert delete_link_res.status_code == 204


def test_media_link_duplicate_returns_409() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    source_res = client.post("/media-items", json={"type": "book", "title": "Book B"}, headers=headers)
    target_res = client.post(
        "/media-items", json={"type": "audiobook", "title": "Audio B"}, headers=headers
    )
    source_id = source_res.json()["id"]
    target_id = target_res.json()["id"]

    first = client.post(
        "/media-links",
        json={
            "source_media_id": source_id,
            "target_media_id": target_id,
            "relation_type": "audioversion",
        },
        headers=headers,
    )
    assert first.status_code == 201

    second = client.post(
        "/media-links",
        json={
            "source_media_id": source_id,
            "target_media_id": target_id,
            "relation_type": "audioversion",
        },
        headers=headers,
    )
    assert second.status_code == 409


def test_related_link_mirrored_duplicate_returns_409() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    first_item = client.post("/media-items", json={"type": "book", "title": "One"}, headers=headers)
    second_item = client.post("/media-items", json={"type": "video", "title": "Two"}, headers=headers)
    first_id = first_item.json()["id"]
    second_id = second_item.json()["id"]

    first_link = client.post(
        "/media-links",
        json={
            "source_media_id": first_id,
            "target_media_id": second_id,
            "relation_type": "related",
        },
        headers=headers,
    )
    assert first_link.status_code == 201

    mirrored_link = client.post(
        "/media-links",
        json={
            "source_media_id": second_id,
            "target_media_id": first_id,
            "relation_type": "related",
        },
        headers=headers,
    )
    assert mirrored_link.status_code == 409


def test_media_items_pagination() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    for idx in range(3):
        create_res = client.post(
            "/media-items",
            json={"type": "book", "title": f"Book {idx}"},
            headers=headers,
        )
        assert create_res.status_code == 201

    page_one = client.get("/media-items?limit=2&offset=0", headers=headers)
    assert page_one.status_code == 200
    page_one_data = page_one.json()
    assert page_one_data["limit"] == 2
    assert page_one_data["offset"] == 0
    assert page_one_data["total"] >= 3
    assert len(page_one_data["items"]) == 2

    page_two = client.get("/media-items?limit=2&offset=2", headers=headers)
    assert page_two.status_code == 200
    page_two_data = page_two.json()
    assert page_two_data["limit"] == 2
    assert page_two_data["offset"] == 2
    assert page_two_data["total"] >= 3


def test_media_item_blank_title_returns_422() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    create_res = client.post(
        "/media-items",
        json={"type": "book", "title": "   "},
        headers=headers,
    )
    assert create_res.status_code == 422


def test_cannot_link_deleted_media_item() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    source_res = client.post("/media-items", json={"type": "book", "title": "Src"}, headers=headers)
    target_res = client.post("/media-items", json={"type": "video", "title": "Tgt"}, headers=headers)
    source_id = source_res.json()["id"]
    target_id = target_res.json()["id"]

    delete_res = client.delete(f"/media-items/{source_id}", headers=headers)
    assert delete_res.status_code == 204

    link_res = client.post(
        "/media-links",
        json={
            "source_media_id": source_id,
            "target_media_id": target_id,
            "relation_type": "related",
        },
        headers=headers,
    )
    assert link_res.status_code == 400


def test_media_items_filter_search_and_sort() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    first = client.post(
        "/media-items",
        json={"type": "book", "title": "Beta Book", "author": "Alice"},
        headers=headers,
    )
    second = client.post(
        "/media-items",
        json={"type": "book", "title": "Alpha Book", "author": "Bob"},
        headers=headers,
    )
    third = client.post(
        "/media-items",
        json={"type": "video", "title": "Gamma Movie", "author": "Alice"},
        headers=headers,
    )
    assert first.status_code == 201
    assert second.status_code == 201
    assert third.status_code == 201

    by_type = client.get("/media-items?type=book", headers=headers)
    assert by_type.status_code == 200
    by_type_data = by_type.json()
    assert by_type_data["total"] == 2
    assert all(item["type"] == "book" for item in by_type_data["items"])

    by_search = client.get("/media-items?q=Alice", headers=headers)
    assert by_search.status_code == 200
    by_search_data = by_search.json()
    assert by_search_data["total"] == 2
    assert all("Alice" in (item.get("author") or "") for item in by_search_data["items"])

    sorted_asc = client.get("/media-items?type=book&sort_by=title&order=asc", headers=headers)
    assert sorted_asc.status_code == 200
    sorted_data = sorted_asc.json()
    titles = [item["title"] for item in sorted_data["items"]]
    assert titles == sorted(titles)


def test_media_progress_get_and_put_flow() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    create_res = client.post(
        "/media-items",
        json={"type": "video", "title": "Progress Video"},
        headers=headers,
    )
    assert create_res.status_code == 201
    media_id = create_res.json()["id"]

    get_initial = client.get(f"/media-items/{media_id}/progress", headers=headers)
    assert get_initial.status_code == 200
    initial_data = get_initial.json()
    assert initial_data["position_seconds"] == 0
    assert initial_data["duration_seconds"] is None
    assert float(initial_data["progress_percent"]) == 0.0
    assert initial_data["is_completed"] is False

    put_res = client.put(
        f"/media-items/{media_id}/progress",
        json={"position_seconds": 120, "duration_seconds": 300, "is_completed": False},
        headers=headers,
    )
    assert put_res.status_code == 200
    progress_data = put_res.json()
    assert progress_data["position_seconds"] == 120
    assert progress_data["duration_seconds"] == 300
    assert float(progress_data["progress_percent"]) == 40.0
    assert progress_data["is_completed"] is False

    complete_res = client.put(
        f"/media-items/{media_id}/progress",
        json={"position_seconds": 300, "duration_seconds": 300, "is_completed": True},
        headers=headers,
    )
    assert complete_res.status_code == 200
    complete_data = complete_res.json()
    assert float(complete_data["progress_percent"]) == 100.0
    assert complete_data["is_completed"] is True


def test_media_file_upload_complete_and_stream_flow() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    create_media = client.post(
        "/media-items",
        json={"type": "audiobook", "title": "Audio Upload"},
        headers=headers,
    )
    assert create_media.status_code == 201
    media_id = create_media.json()["id"]

    upload_init_res = client.post(
        f"/media-items/{media_id}/files/upload",
        json={
            "filename": "chapter1.mp3",
            "content_type": "audio/mpeg",
            "file_size": 1024,
        },
        headers=headers,
    )
    assert upload_init_res.status_code == 201
    upload_data = upload_init_res.json()
    file_id = upload_data["file_id"]
    assert upload_data["upload_status"] == "pending"
    assert upload_data["method"] == "PUT"
    assert upload_data["upload_url"].startswith("http")

    complete_res = client.post(f"/media-files/{file_id}/complete", headers=headers)
    assert complete_res.status_code == 200
    complete_data = complete_res.json()
    assert complete_data["upload_status"] == "ready"
    assert complete_data["uploaded_at"] is not None

    stream_res = client.get(f"/media-files/{file_id}/stream", headers=headers)
    assert stream_res.status_code == 200
    stream_data = stream_res.json()
    assert stream_data["file_id"] == file_id
    assert stream_data["media_item_id"] == media_id
    assert stream_data["stream_url"].startswith("http")


def test_stream_url_before_upload_complete_returns_409() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    create_media = client.post(
        "/media-items",
        json={"type": "video", "title": "Pending Video"},
        headers=headers,
    )
    assert create_media.status_code == 201
    media_id = create_media.json()["id"]

    upload_init_res = client.post(
        f"/media-items/{media_id}/files/upload",
        json={
            "filename": "movie.mp4",
            "content_type": "video/mp4",
            "file_size": 2048,
        },
        headers=headers,
    )
    assert upload_init_res.status_code == 201
    file_id = upload_init_res.json()["file_id"]

    stream_res = client.get(f"/media-files/{file_id}/stream", headers=headers)
    assert stream_res.status_code == 409


def test_upload_rejects_unsupported_content_type() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    create_media = client.post(
        "/media-items",
        json={"type": "audiobook", "title": "Bad Mime"},
        headers=headers,
    )
    assert create_media.status_code == 201
    media_id = create_media.json()["id"]

    upload_init_res = client.post(
        f"/media-items/{media_id}/files/upload",
        json={
            "filename": "book.exe",
            "content_type": "application/octet-stream",
            "file_size": 1000,
        },
        headers=headers,
    )
    assert upload_init_res.status_code == 400


def test_upload_rejects_too_large_file() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    create_media = client.post(
        "/media-items",
        json={"type": "video", "title": "Big File"},
        headers=headers,
    )
    assert create_media.status_code == 201
    media_id = create_media.json()["id"]

    upload_init_res = client.post(
        f"/media-items/{media_id}/files/upload",
        json={
            "filename": "movie.mp4",
            "content_type": "video/mp4",
            "file_size": 600_000_000,
        },
        headers=headers,
    )
    assert upload_init_res.status_code == 400


def test_e2e_upload_stream_and_save_progress() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    create_media = client.post(
        "/media-items",
        json={"type": "video", "title": "End-to-end"},
        headers=headers,
    )
    assert create_media.status_code == 201
    media_id = create_media.json()["id"]

    upload_init_res = client.post(
        f"/media-items/{media_id}/files/upload",
        json={
            "filename": "episode.mp4",
            "content_type": "video/mp4",
            "file_size": 50_000_000,
        },
        headers=headers,
    )
    assert upload_init_res.status_code == 201
    file_id = upload_init_res.json()["file_id"]

    complete_res = client.post(f"/media-files/{file_id}/complete", headers=headers)
    assert complete_res.status_code == 200

    stream_res = client.get(f"/media-files/{file_id}/stream", headers=headers)
    assert stream_res.status_code == 200
    assert stream_res.json()["stream_url"].startswith("http")

    save_progress_res = client.put(
        f"/media-items/{media_id}/progress",
        json={"position_seconds": 95, "duration_seconds": 300, "is_completed": False},
        headers=headers,
    )
    assert save_progress_res.status_code == 200
    saved_progress = save_progress_res.json()
    assert saved_progress["position_seconds"] == 95
    assert float(saved_progress["progress_percent"]) > 0
