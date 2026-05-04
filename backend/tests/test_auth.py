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
