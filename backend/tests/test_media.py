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
