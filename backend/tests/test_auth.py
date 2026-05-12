from uuid import uuid4

import pyotp
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _email(prefix: str) -> str:
    return f"{prefix}_{uuid4().hex[:8]}@test.com"


def test_register_and_login_success() -> None:
    email = _email("reg")
    register_res = client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "Test123!",
            "display_name": "Tester",
        },
    )
    assert register_res.status_code == 201

    login_res = client.post(
        "/auth/login",
        json={"email": email, "password": "Test123!"},
    )
    assert login_res.status_code == 200
    data = login_res.json()
    assert data["requires_2fa"] is False
    assert data["access_token"]
    assert data["refresh_token"]
    assert data["email"] == email
    assert data["display_name"] == "Tester"


def test_login_wrong_password_returns_401() -> None:
    email = _email("badpwd")
    client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "Test123!",
            "display_name": "Tester",
        },
    )

    login_res = client.post(
        "/auth/login",
        json={"email": email, "password": "WrongPass123!"},
    )
    assert login_res.status_code == 401


def test_refresh_returns_new_tokens() -> None:
    email = _email("refresh")
    client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "Test123!",
            "display_name": "Tester",
        },
    )
    login_res = client.post("/auth/login", json={"email": email, "password": "Test123!"})
    refresh_token = login_res.json()["refresh_token"]

    refresh_res = client.post("/auth/refresh", json={"refresh_token": refresh_token})
    assert refresh_res.status_code == 200
    data = refresh_res.json()
    assert data["access_token"]
    assert data["refresh_token"]


def test_2fa_setup_and_verify_success() -> None:
    email = _email("twofa")
    client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "Test123!",
            "display_name": "Tester",
        },
    )
    setup_res = client.post(
        "/auth/2fa/setup",
        json={"email": email, "password": "Test123!"},
    )
    assert setup_res.status_code == 200
    setup_data = setup_res.json()
    assert setup_data["secret"]
    assert setup_data["otp_auth_uri"]

    login_res = client.post("/auth/login", json={"email": email, "password": "Test123!"})
    assert login_res.status_code == 200
    login_data = login_res.json()
    assert login_data["requires_2fa"] is True
    challenge_token = login_data["challenge_token"]

    otp_code = pyotp.TOTP(setup_data["secret"]).now()
    verify_res = client.post(
        "/auth/2fa/verify",
        json={
            "challenge_token": challenge_token,
            "otp_code": otp_code,
        },
    )
    assert verify_res.status_code == 200
    verify_data = verify_res.json()
    assert verify_data["access_token"]
    assert verify_data["refresh_token"]
    assert verify_data["email"] == email
    assert verify_data["display_name"] == "Tester"


def test_me_get_and_patch_display_name() -> None:
    email = _email("me_user")
    client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "Test123!",
            "display_name": "Ann",
        },
    )
    login_res = client.post("/auth/login", json={"email": email, "password": "Test123!"})
    token = login_res.json()["access_token"]

    me_res = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_res.status_code == 200
    assert me_res.json()["display_name"] == "Ann"

    patch_res = client.patch(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"display_name": "Anna"},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["display_name"] == "Anna"


def test_me_patch_email_requires_password() -> None:
    email = _email("email_change")
    client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "Test123!",
            "display_name": "U",
        },
    )
    login_res = client.post("/auth/login", json={"email": email, "password": "Test123!"})
    token = login_res.json()["access_token"]
    new_email = _email("email_new")

    bad = client.patch(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"email": new_email},
    )
    assert bad.status_code == 401

    ok = client.patch(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "display_name": "U",
            "email": new_email,
            "current_password": "Test123!",
        },
    )
    assert ok.status_code == 200
    assert ok.json()["email"] == new_email


def test_change_password() -> None:
    email = _email("pwd_change")
    client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "Test123!",
            "display_name": "P",
        },
    )
    login_res = client.post("/auth/login", json={"email": email, "password": "Test123!"})
    token = login_res.json()["access_token"]

    cp = client.post(
        "/auth/change-password",
        headers={"Authorization": f"Bearer {token}"},
        json={"current_password": "Test123!", "new_password": "NewTest123!"},
    )
    assert cp.status_code == 204

    old_login = client.post("/auth/login", json={"email": email, "password": "Test123!"})
    assert old_login.status_code == 401

    new_login = client.post("/auth/login", json={"email": email, "password": "NewTest123!"})
    assert new_login.status_code == 200
