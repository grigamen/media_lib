from uuid import UUID

import pyotp
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.jwt_utils import (
    create_access_token,
    create_refresh_token,
    create_twofa_challenge_token,
    decode_token,
)
from app.models import User
from app.schemas.auth import (
    LoginRequest,
    LoginResponse,
    RefreshRequest,
    RefreshResponse,
    RegisterRequest,
    RegisterResponse,
    TwoFASetupRequest,
    TwoFASetupResponse,
    TwoFAVerifyRequest,
)
from app.security import hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


def _token_pair(user: User) -> tuple[str, str]:
    uid = str(user.id)
    return create_access_token(uid, is_admin=user.is_admin), create_refresh_token(uid)


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> RegisterResponse:
    email = payload.email.lower()

    existing_user = db.scalar(select(User).where(User.email == email))
    if existing_user is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        display_name=payload.display_name.strip(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return RegisterResponse(user_id=user.id, email=user.email, display_name=user.display_name)


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> LoginResponse:
    email = payload.email.lower()
    user = db.scalar(select(User).where(User.email == email))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    if user.twofa_enabled:
        challenge_token = create_twofa_challenge_token(str(user.id))
        return LoginResponse(requires_2fa=True, challenge_token=challenge_token)

    access_token, refresh_token = _token_pair(user)
    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post("/refresh", response_model=RefreshResponse)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)) -> RefreshResponse:
    try:
        data = decode_token(payload.refresh_token)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc

    if data.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token type")

    user_id = data.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token subject")

    user = db.get(User, UUID(user_id))
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    access_token, refresh_token = _token_pair(user)
    return RefreshResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/2fa/setup", response_model=TwoFASetupResponse)
def twofa_setup(payload: TwoFASetupRequest, db: Session = Depends(get_db)) -> TwoFASetupResponse:
    email = payload.email.lower()
    user = db.scalar(select(User).where(User.email == email))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    if user.twofa_enabled and user.twofa_secret:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="2FA already enabled")

    secret = pyotp.random_base32()
    user.twofa_secret = secret
    user.twofa_enabled = True
    db.commit()

    otp_auth_uri = pyotp.TOTP(secret).provisioning_uri(name=user.email, issuer_name="MediaLib")
    return TwoFASetupResponse(secret=secret, otp_auth_uri=otp_auth_uri)


@router.post("/2fa/verify", response_model=RefreshResponse)
def twofa_verify(payload: TwoFAVerifyRequest, db: Session = Depends(get_db)) -> RefreshResponse:
    try:
        data = decode_token(payload.challenge_token)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid challenge token") from exc

    if data.get("type") != "twofa_challenge":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid challenge type")

    user_id = data.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid challenge subject")

    user = db.get(User, UUID(user_id))
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if not user.twofa_enabled or not user.twofa_secret:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="2FA is not enabled")

    otp = pyotp.TOTP(user.twofa_secret)
    if not otp.verify(payload.otp_code, valid_window=1):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid OTP code")

    access_token, refresh_token = _token_pair(user)
    return RefreshResponse(access_token=access_token, refresh_token=refresh_token)
