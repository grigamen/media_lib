from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.db import SessionLocal
from app.main import app
from app.models import User

client = TestClient(app)


def _make_user_admin(email: str) -> None:
    db = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.email == email.lower()))
        assert user is not None
        user.is_admin = True
        db.commit()
    finally:
        db.close()


def _login_token(email: str, password: str = "Test123!") -> str:
    login_res = client.post("/auth/login", json={"email": email, "password": password})
    assert login_res.status_code == 200
    return login_res.json()["access_token"]


def _approve_as_admin(media_item_id: str) -> None:
    admin_email = f"adm_{uuid4().hex[:8]}@test.com"
    password = "Test123!"
    reg = client.post(
        "/auth/register",
        json={"email": admin_email, "password": password, "display_name": "Admin"},
    )
    assert reg.status_code == 201
    _make_user_admin(admin_email)
    admin_token = _login_token(admin_email, password)
    appr = client.post(
        f"/admin/media-items/{media_item_id}/approve",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert appr.status_code == 200


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
        json={
            "type": "book",
            "title": "Dune",
            "author": "Frank Herbert",
            "cover_url": "https://example.com/dune.jpg",
            "genres": ["Sci-Fi", "Classic"],
        },
        headers=headers,
    )
    assert create_res.status_code == 201
    item = create_res.json()
    media_id = item["id"]
    assert item["moderation_status"] == "pending"
    assert item["cover_url"] == "https://example.com/dune.jpg"
    assert item["genres"] == ["Sci-Fi", "Classic"]

    list_res = client.get("/media-items", headers=headers)
    assert list_res.status_code == 200
    list_data = list_res.json()
    assert list_data["total"] >= 1
    assert any(entry["id"] == media_id for entry in list_data["items"])

    patch_res = client.patch(
        f"/media-items/{media_id}",
        json={
            "title": "Dune Updated",
            "cover_url": "https://example.com/dune-2.jpg",
            "genres": ["Sci-Fi", "Adventure", " Sci-Fi "],
        },
        headers=headers,
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["title"] == "Dune Updated"
    assert patch_res.json()["cover_url"] == "https://example.com/dune-2.jpg"
    assert patch_res.json()["genres"] == ["Sci-Fi", "Adventure"]

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
    marker = uuid4().hex[:8]

    first = client.post(
        "/media-items",
        json={"type": "book", "title": f"{marker} Beta Book", "author": f"Alice {marker}"},
        headers=headers,
    )
    second = client.post(
        "/media-items",
        json={"type": "book", "title": f"{marker} Alpha Book", "author": f"Bob {marker}"},
        headers=headers,
    )
    third = client.post(
        "/media-items",
        json={"type": "video", "title": f"{marker} Gamma Movie", "author": f"Alice {marker}"},
        headers=headers,
    )
    assert first.status_code == 201
    assert second.status_code == 201
    assert third.status_code == 201

    by_type = client.get(f"/media-items?type=book&q={marker}", headers=headers)
    assert by_type.status_code == 200
    by_type_data = by_type.json()
    assert by_type_data["total"] == 2
    assert all(item["type"] == "book" for item in by_type_data["items"])

    by_search = client.get(f"/media-items?q=Alice {marker}", headers=headers)
    assert by_search.status_code == 200
    by_search_data = by_search.json()
    assert by_search_data["total"] == 2
    assert all(marker in (item.get("author") or "") for item in by_search_data["items"])

    sorted_asc = client.get(
        f"/media-items?type=book&q={marker}&sort_by=title&order=asc",
        headers=headers,
    )
    assert sorted_asc.status_code == 200
    sorted_data = sorted_asc.json()
    titles = [item["title"] for item in sorted_data["items"]]
    assert titles == sorted(titles)


def test_media_items_filter_types_list_and_genres() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}
    marker = uuid4().hex[:8]

    for spec in (
        {"type": "book", "title": f"A {marker}", "genres": ["Фэнтези", "Ужасы"]},
        {"type": "audiobook", "title": f"B {marker}", "genres": ["Фэнтези"]},
        {"type": "video", "title": f"C {marker}", "genres": ["Комедия"]},
    ):
        r = client.post("/media-items", json=spec, headers=headers)
        assert r.status_code == 201

    both = client.get(f"/media-items?types=book&types=audiobook&q={marker}", headers=headers)
    assert both.status_code == 200
    assert both.json()["total"] == 2

    fantasy = client.get(f"/media-items?genres=Фэнтези&q={marker}", headers=headers)
    assert fantasy.status_code == 200
    assert fantasy.json()["total"] == 2

    fantasy_ci = client.get(f"/media-items?genres=фэнтези&q={marker}", headers=headers)
    assert fantasy_ci.status_code == 200
    assert fantasy_ci.json()["total"] == 2


def test_media_genres_includes_existing_and_defaults() -> None:
    admin_email = f"genres_adm_{uuid4().hex[:8]}@test.com"
    password = "Test123!"
    reg = client.post(
        "/auth/register",
        json={"email": admin_email, "password": password, "display_name": "GA"},
    )
    assert reg.status_code == 201
    _make_user_admin(admin_email)
    token = _login_token(admin_email, password)
    headers = {"Authorization": f"Bearer {token}"}

    create_res = client.post(
        "/media-items",
        json={"type": "book", "title": "Genres Book", "genres": ["Киберпанк", "Фантастика"]},
        headers=headers,
    )
    assert create_res.status_code == 201
    mid = create_res.json()["id"]
    assert create_res.json()["moderation_status"] == "pending"
    appr = client.post(
        f"/admin/media-items/{mid}/approve",
        headers=headers,
    )
    assert appr.status_code == 200

    genres_res = client.get("/media-genres", headers=headers)
    assert genres_res.status_code == 200
    genres = genres_res.json()["genres"]
    assert "Киберпанк" in genres
    assert "Фантастика" in genres
    assert "Классика" in genres


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

    list_res = client.get(f"/media-items/{media_id}/files", headers=headers)
    assert list_res.status_code == 200
    listed = list_res.json()
    assert len(listed) == 1
    assert listed[0]["id"] == file_id
    assert listed[0]["upload_status"] == "ready"
    assert listed[0]["content_type"] == "audio/mpeg"

    other_token = _register_and_token()
    other_headers = {"Authorization": f"Bearer {other_token}"}
    forbidden = client.get(f"/media-items/{media_id}/files", headers=other_headers)
    assert forbidden.status_code == 404


def test_media_item_files_lists_multiple_ready_attachments() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}

    create_media = client.post(
        "/media-items",
        json={"type": "audiobook", "title": "Multi file"},
        headers=headers,
    )
    assert create_media.status_code == 201
    media_id = create_media.json()["id"]

    ids: list[str] = []
    for name in ("a.mp3", "b.mp3"):
        upload_init_res = client.post(
            f"/media-items/{media_id}/files/upload",
            json={
                "filename": name,
                "content_type": "audio/mpeg",
                "file_size": 512,
            },
            headers=headers,
        )
        assert upload_init_res.status_code == 201
        fid = upload_init_res.json()["file_id"]
        complete_res = client.post(f"/media-files/{fid}/complete", headers=headers)
        assert complete_res.status_code == 200
        ids.append(fid)

    list_res = client.get(f"/media-items/{media_id}/files", headers=headers)
    assert list_res.status_code == 200
    listed = list_res.json()
    assert len(listed) == 2
    ready_ids = {row["id"] for row in listed if row["upload_status"] == "ready"}
    assert ready_ids == set(ids)


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


def test_other_user_can_read_item_stream_and_progress() -> None:
    owner_token = _register_and_token()
    owner_headers = {"Authorization": f"Bearer {owner_token}"}

    create_media = client.post(
        "/media-items",
        json={"type": "video", "title": "Shared Video"},
        headers=owner_headers,
    )
    assert create_media.status_code == 201
    media_id = create_media.json()["id"]

    upload_init_res = client.post(
        f"/media-items/{media_id}/files/upload",
        json={
            "filename": "shared.mp4",
            "content_type": "video/mp4",
            "file_size": 1024,
        },
        headers=owner_headers,
    )
    assert upload_init_res.status_code == 201
    file_id = upload_init_res.json()["file_id"]

    complete_res = client.post(f"/media-files/{file_id}/complete", headers=owner_headers)
    assert complete_res.status_code == 200

    _approve_as_admin(media_id)

    viewer_token = _register_and_token()
    viewer_headers = {"Authorization": f"Bearer {viewer_token}"}

    list_res = client.get("/media-items", headers=viewer_headers)
    assert list_res.status_code == 200
    assert any(item["id"] == media_id for item in list_res.json()["items"])

    files_list = client.get(f"/media-items/{media_id}/files", headers=viewer_headers)
    assert files_list.status_code == 200
    assert any(row["id"] == file_id for row in files_list.json())

    stream_res = client.get(f"/media-files/{file_id}/stream", headers=viewer_headers)
    assert stream_res.status_code == 200
    assert stream_res.json()["file_id"] == file_id

    get_progress = client.get(f"/media-items/{media_id}/progress", headers=viewer_headers)
    assert get_progress.status_code == 200
    assert get_progress.json()["media_item_id"] == media_id

    put_progress = client.put(
        f"/media-items/{media_id}/progress",
        json={"position_seconds": 15, "duration_seconds": 120, "is_completed": False},
        headers=viewer_headers,
    )
    assert put_progress.status_code == 200
    assert put_progress.json()["position_seconds"] == 15


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


def test_non_admin_cannot_delete_other_users_media_item() -> None:
    owner_token = _register_and_token()
    other_token = _register_and_token()
    owner_headers = {"Authorization": f"Bearer {owner_token}"}
    create_res = client.post(
        "/media-items",
        json={"type": "book", "title": "Owners only"},
        headers=owner_headers,
    )
    assert create_res.status_code == 201
    media_id = create_res.json()["id"]

    del_res = client.delete(
        f"/media-items/{media_id}",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert del_res.status_code == 404


def test_admin_can_delete_other_users_media_item() -> None:
    from sqlalchemy import select

    from app.db import SessionLocal
    from app.models import User

    owner_token = _register_and_token()
    owner_headers = {"Authorization": f"Bearer {owner_token}"}
    create_res = client.post(
        "/media-items",
        json={"type": "book", "title": "Admin purge target"},
        headers=owner_headers,
    )
    assert create_res.status_code == 201
    media_id = create_res.json()["id"]

    admin_email = f"admin_{uuid4().hex[:8]}@test.com"
    password = "Test123!"
    reg = client.post(
        "/auth/register",
        json={"email": admin_email, "password": password, "display_name": "Admin"},
    )
    assert reg.status_code == 201

    db = SessionLocal()
    try:
        admin_user = db.scalar(select(User).where(User.email == admin_email))
        assert admin_user is not None
        admin_user.is_admin = True
        db.commit()
    finally:
        db.close()

    login_res = client.post("/auth/login", json={"email": admin_email, "password": password})
    assert login_res.status_code == 200
    admin_headers = {"Authorization": f"Bearer {login_res.json()['access_token']}"}

    del_res = client.delete(f"/media-items/{media_id}", headers=admin_headers)
    assert del_res.status_code == 204


def test_pending_work_invisible_to_other_user_until_approved() -> None:
    owner_token = _register_and_token()
    owner_headers = {"Authorization": f"Bearer {owner_token}"}
    create_res = client.post(
        "/media-items",
        json={"type": "book", "title": "Private until ok"},
        headers=owner_headers,
    )
    assert create_res.status_code == 201
    media_id = create_res.json()["id"]
    assert create_res.json()["moderation_status"] == "pending"

    other_token = _register_and_token()
    other_headers = {"Authorization": f"Bearer {other_token}"}
    list_res = client.get("/media-items", headers=other_headers)
    assert list_res.status_code == 200
    assert not any(x["id"] == media_id for x in list_res.json()["items"])

    get_res = client.get(f"/media-items/{media_id}", headers=other_headers)
    assert get_res.status_code == 404

    _approve_as_admin(media_id)

    list2 = client.get("/media-items", headers=other_headers)
    assert any(x["id"] == media_id for x in list2.json()["items"])
    get2 = client.get(f"/media-items/{media_id}", headers=other_headers)
    assert get2.status_code == 200


def test_user_can_see_own_pending_item() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}
    create_res = client.post(
        "/media-items",
        json={"type": "book", "title": "Mine pending"},
        headers=headers,
    )
    assert create_res.status_code == 201
    mid = create_res.json()["id"]
    list_res = client.get("/media-items", headers=headers)
    assert any(x["id"] == mid for x in list_res.json()["items"])


def test_non_admin_cannot_approve() -> None:
    token = _register_and_token()
    headers = {"Authorization": f"Bearer {token}"}
    create_res = client.post("/media-items", json={"type": "book", "title": "X"}, headers=headers)
    mid = create_res.json()["id"]
    appr = client.post(f"/admin/media-items/{mid}/approve", headers=headers)
    assert appr.status_code == 403


def test_admin_create_also_pending_until_approved() -> None:
    admin_email = f"adm_create_{uuid4().hex[:8]}@test.com"
    password = "Test123!"
    assert (
        client.post(
            "/auth/register",
            json={"email": admin_email, "password": password, "display_name": "A"},
        ).status_code
        == 201
    )
    _make_user_admin(admin_email)
    token = _login_token(admin_email, password)
    headers = {"Authorization": f"Bearer {token}"}
    create_res = client.post(
        "/media-items",
        json={"type": "book", "title": "Admin book"},
        headers=headers,
    )
    assert create_res.status_code == 201
    assert create_res.json()["moderation_status"] == "pending"


def test_admin_reject_marks_rejected() -> None:
    owner_token = _register_and_token()
    owner_headers = {"Authorization": f"Bearer {owner_token}"}
    create_res = client.post(
        "/media-items",
        json={"type": "book", "title": "Reject me"},
        headers=owner_headers,
    )
    mid = create_res.json()["id"]
    admin_email = f"adm_r_{uuid4().hex[:8]}@test.com"
    password = "Test123!"
    client.post(
        "/auth/register",
        json={"email": admin_email, "password": password, "display_name": "R"},
    )
    _make_user_admin(admin_email)
    atok = _login_token(admin_email, password)
    rej = client.post(
        f"/admin/media-items/{mid}/reject",
        headers={"Authorization": f"Bearer {atok}"},
    )
    assert rej.status_code == 200
    assert rej.json()["moderation_status"] == "rejected"
    get_owner = client.get(f"/media-items/{mid}", headers=owner_headers)
    assert get_owner.status_code == 200
    assert get_owner.json()["moderation_status"] == "rejected"


def test_owner_edit_after_rejection_resubmits_as_pending() -> None:
    owner_token = _register_and_token()
    oh = {"Authorization": f"Bearer {owner_token}"}
    mid = client.post("/media-items", json={"type": "book", "title": "R"}, headers=oh).json()["id"]
    admin_email = f"adm_re_{uuid4().hex[:8]}@test.com"
    pw = "Test123!"
    client.post(
        "/auth/register",
        json={"email": admin_email, "password": pw, "display_name": "R"},
    )
    _make_user_admin(admin_email)
    atok = _login_token(admin_email, pw)
    client.post(
        f"/admin/media-items/{mid}/reject",
        headers={"Authorization": f"Bearer {atok}"},
    )
    patch = client.patch(f"/media-items/{mid}", json={"description": "fixed"}, headers=oh)
    assert patch.status_code == 200
    assert patch.json()["moderation_status"] == "pending"


def test_admin_can_filter_media_items_by_moderation_status() -> None:
    admin_email = f"adm_filt_{uuid4().hex[:8]}@test.com"
    password = "Test123!"
    client.post(
        "/auth/register",
        json={"email": admin_email, "password": password, "display_name": "F"},
    )
    _make_user_admin(admin_email)
    atok = _login_token(admin_email, password)
    ah = {"Authorization": f"Bearer {atok}"}
    r1 = client.post(
        "/media-items",
        json={"type": "book", "title": "FilterPending"},
        headers=ah,
    )
    assert r1.status_code == 201
    mid_pending = r1.json()["id"]
    r2 = client.post(
        "/media-items",
        json={"type": "video", "title": "FilterVid"},
        headers=ah,
    )
    assert r2.status_code == 201
    mid_other = r2.json()["id"]
    client.post(f"/admin/media-items/{mid_other}/approve", headers=ah)

    only_pending = client.get("/media-items?moderation_status=pending&limit=50", headers=ah)
    assert only_pending.status_code == 200
    assert only_pending.json()["total"] >= 1
    ids = {row["id"] for row in only_pending.json()["items"]}
    assert mid_pending in ids
    assert mid_other not in ids

    only_approved = client.get("/media-items?moderation_status=approved&limit=50", headers=ah)
    assert only_approved.status_code == 200
    ids_ok = {row["id"] for row in only_approved.json()["items"]}
    assert mid_other in ids_ok
    assert mid_pending not in ids_ok


def test_admin_exclude_pending_hides_queue() -> None:
    admin_email = f"adm_ex_{uuid4().hex[:8]}@test.com"
    password = "Test123!"
    client.post(
        "/auth/register",
        json={"email": admin_email, "password": password, "display_name": "E"},
    )
    _make_user_admin(admin_email)
    atok = _login_token(admin_email, password)
    ah = {"Authorization": f"Bearer {atok}"}
    r1 = client.post(
        "/media-items",
        json={"type": "book", "title": "StillPending"},
        headers=ah,
    )
    assert r1.status_code == 201
    mid_p = r1.json()["id"]
    r2 = client.post(
        "/media-items",
        json={"type": "audiobook", "title": "ApprovedNow"},
        headers=ah,
    )
    assert r2.status_code == 201
    mid_a = r2.json()["id"]
    appr = client.post(f"/admin/media-items/{mid_a}/approve", headers=ah)
    assert appr.status_code == 200

    ex = client.get("/media-items?exclude_pending=true&limit=100", headers=ah)
    assert ex.status_code == 200
    ids = {row["id"] for row in ex.json()["items"]}
    assert mid_p not in ids
    assert mid_a in ids


def test_non_admin_cannot_use_exclude_pending() -> None:
    tok = _register_and_token()
    h = {"Authorization": f"Bearer {tok}"}
    bad = client.get("/media-items?exclude_pending=true", headers=h)
    assert bad.status_code == 403


def test_non_admin_cannot_use_moderation_status_filter() -> None:
    tok = _register_and_token()
    h = {"Authorization": f"Bearer {tok}"}
    bad = client.get("/media-items?moderation_status=pending", headers=h)
    assert bad.status_code == 403


def test_admin_default_list_hides_other_users_rejected_items() -> None:
    owner_token = _register_and_token()
    oh = {"Authorization": f"Bearer {owner_token}"}
    create_res = client.post(
        "/media-items",
        json={"type": "video", "title": "RejectedVid"},
        headers=oh,
    )
    assert create_res.status_code == 201
    mid = create_res.json()["id"]

    admin_email = f"adm_hide_{uuid4().hex[:8]}@test.com"
    password = "Test123!"
    client.post(
        "/auth/register",
        json={"email": admin_email, "password": password, "display_name": "H"},
    )
    _make_user_admin(admin_email)
    atok = _login_token(admin_email, password)
    ah = {"Authorization": f"Bearer {atok}"}

    rej = client.post(f"/admin/media-items/{mid}/reject", headers=ah)
    assert rej.status_code == 200

    default_list = client.get("/media-items?limit=100", headers=ah)
    assert default_list.status_code == 200
    ids = {row["id"] for row in default_list.json()["items"]}
    assert mid not in ids

    rejected_list = client.get("/media-items?moderation_status=rejected&limit=100", headers=ah)
    assert rejected_list.status_code == 200
    rej_ids = {row["id"] for row in rejected_list.json()["items"]}
    assert mid in rej_ids
