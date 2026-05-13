from __future__ import annotations

import hmac
import logging
from datetime import timedelta
from typing import Callable
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.config import settings
from app.db import get_db
from app.jwt_utils import (
    create_access_token,
    create_refresh_token,
    create_twofa_challenge_token,
    decode_token,
)
from app.mail import send_login_otp_email, send_profile_otp_email
from app.models import TwoFAEmailChallenge, User
from app.models.user import utcnow
from app.schemas.auth import (
    Email2FAEnableConfirmRequest,
    Email2FAEnableStartRequest,
    Email2FADisableRequest,
    LoginRequest,
    LoginResponse,
    MePatchRequest,
    MeResponse,
    PasswordChangeRequest,
    RefreshRequest,
    RefreshResponse,
    RegisterRequest,
    RegisterResponse,
    TwoFAResendRequest,
    TwoFAVerifyRequest,
)
from app.security import hash_password, verify_password
from app.twofa_otp import generate_numeric_otp, hash_otp_code

router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger(__name__)


def _token_pair(user: User) -> tuple[str, str]:
    uid = str(user.id)
    return create_access_token(uid, is_admin=user.is_admin), create_refresh_token(uid)


def _invalidate_pending_challenges(db: Session, user_id: UUID, purpose: str) -> None:
    now = utcnow()
    db.execute(
        update(TwoFAEmailChallenge)
        .where(
            TwoFAEmailChallenge.user_id == user_id,
            TwoFAEmailChallenge.purpose == purpose,
            TwoFAEmailChallenge.consumed_at.is_(None),
        )
        .values(consumed_at=now)
    )


def _active_challenge(db: Session, user_id: UUID, purpose: str) -> TwoFAEmailChallenge | None:
    return db.scalar(
        select(TwoFAEmailChallenge)
        .where(
            TwoFAEmailChallenge.user_id == user_id,
            TwoFAEmailChallenge.purpose == purpose,
            TwoFAEmailChallenge.consumed_at.is_(None),
            TwoFAEmailChallenge.expires_at > utcnow(),
        )
        .order_by(TwoFAEmailChallenge.created_at.desc())
    )


def _create_otp_challenge(
    db: Session,
    *,
    user: User,
    purpose: str,
    send_mail: Callable[[str, str, int], None],
) -> None:
    _invalidate_pending_challenges(db, user.id, purpose)
    code = generate_numeric_otp()
    row = TwoFAEmailChallenge(
        user_id=user.id,
        purpose=purpose,
        code_hash=hash_otp_code(code, user.id),
        expires_at=utcnow() + timedelta(minutes=settings.TWOFA_CODE_TTL_MIN),
        attempts=0,
        last_sent_at=utcnow(),
    )
    db.add(row)
    try:
        db.flush()
        send_mail(user.email, code, settings.TWOFA_CODE_TTL_MIN)
    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        logger.exception("Не удалось отправить письмо с OTP (%s)", purpose)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Не удалось отправить письмо с кодом",
        ) from None
    db.commit()


def _decode_login_challenge(token: str) -> UUID:
    try:
        data = decode_token(token)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid challenge token") from exc
    if data.get("type") != "twofa_challenge":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid challenge type")
    sub = data.get("sub")
    if not sub:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid challenge subject")
    try:
        return UUID(sub)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid user id in challenge") from exc


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
        _create_otp_challenge(
            db,
            user=user,
            purpose="login",
            send_mail=send_login_otp_email,
        )
        challenge_token = create_twofa_challenge_token(str(user.id))
        return LoginResponse(
            requires_2fa=True,
            challenge_token=challenge_token,
            email=user.email,
            display_name=user.display_name,
            message="На ваш email отправлен код подтверждения",
        )

    access_token, refresh_token = _token_pair(user)
    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        email=user.email,
        display_name=user.display_name,
        twofa_enabled=False,
    )


@router.post("/2fa/email/verify", response_model=RefreshResponse)
def twofa_email_verify_login(payload: TwoFAVerifyRequest, db: Session = Depends(get_db)) -> RefreshResponse:
    user_id = _decode_login_challenge(payload.challenge_token)
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if not user.twofa_enabled:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="2FA is not enabled for this account")

    challenge = _active_challenge(db, user_id, "login")
    if challenge is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Нет активного кода — войдите снова")

    if challenge.attempts >= settings.TWOFA_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Превышено число попыток — запросите новый код",
        )

    expected = hash_otp_code(payload.otp_code.strip(), user_id)
    if not hmac.compare_digest(challenge.code_hash, expected):
        challenge.attempts += 1
        db.add(challenge)
        db.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Неверный код")

    challenge.consumed_at = utcnow()
    db.add(challenge)
    db.commit()

    access_token, refresh_token = _token_pair(user)
    return RefreshResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        email=user.email,
        display_name=user.display_name,
        twofa_enabled=user.twofa_enabled,
    )


@router.post("/2fa/email/resend", response_model=LoginResponse)
def twofa_email_resend(payload: TwoFAResendRequest, db: Session = Depends(get_db)) -> LoginResponse:
    user_id = _decode_login_challenge(payload.challenge_token)
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if not user.twofa_enabled:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="2FA is not enabled")

    challenge = _active_challenge(db, user_id, "login")
    if challenge is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Нет активного запроса — войдите снова")

    elapsed = (utcnow() - challenge.last_sent_at).total_seconds()
    if elapsed < settings.TWOFA_RESEND_COOLDOWN_SEC:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Повторная отправка через {int(settings.TWOFA_RESEND_COOLDOWN_SEC - elapsed)} с",
        )

    code = generate_numeric_otp()
    challenge.code_hash = hash_otp_code(code, user_id)
    challenge.expires_at = utcnow() + timedelta(minutes=settings.TWOFA_CODE_TTL_MIN)
    challenge.attempts = 0
    challenge.last_sent_at = utcnow()
    db.add(challenge)
    db.commit()
    try:
        send_login_otp_email(user.email, code, settings.TWOFA_CODE_TTL_MIN)
    except Exception:
        logger.exception("resend OTP mail failed")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Не удалось отправить письмо",
        ) from None

    return LoginResponse(
        requires_2fa=True,
        challenge_token=payload.challenge_token,
        email=user.email,
        display_name=user.display_name,
        message="Код отправлен повторно",
    )


@router.post("/2fa/email/enable/start", status_code=status.HTTP_204_NO_CONTENT)
def twofa_email_enable_start(
    payload: Email2FAEnableStartRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    if current_user.twofa_enabled:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="2FA уже включена")
    if not verify_password(payload.current_password, current_user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Неверный пароль")

    _create_otp_challenge(
        db,
        user=current_user,
        purpose="enable",
        send_mail=lambda em, c, ex: send_profile_otp_email(
            em,
            c,
            ex,
            purpose_label="включение двухфакторной аутентификации",
        ),
    )


@router.post("/2fa/email/enable/confirm", status_code=status.HTTP_204_NO_CONTENT)
def twofa_email_enable_confirm(
    payload: Email2FAEnableConfirmRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    if current_user.twofa_enabled:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="2FA уже включена")

    challenge = _active_challenge(db, current_user.id, "enable")
    if challenge is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Сначала запросите код в разделе профиля")

    if challenge.attempts >= settings.TWOFA_MAX_ATTEMPTS:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Слишком много попыток")

    expected = hash_otp_code(payload.code.strip(), current_user.id)
    if not hmac.compare_digest(challenge.code_hash, expected):
        challenge.attempts += 1
        db.add(challenge)
        db.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Неверный код")

    challenge.consumed_at = utcnow()
    current_user.twofa_enabled = True
    current_user.twofa_secret = None
    db.add(challenge)
    db.add(current_user)
    db.commit()


@router.post("/2fa/email/disable", status_code=status.HTTP_204_NO_CONTENT)
def twofa_email_disable(
    payload: Email2FADisableRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    if not current_user.twofa_enabled:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="2FA уже выключена")
    if not verify_password(payload.current_password, current_user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Неверный пароль")

    current_user.twofa_enabled = False
    current_user.twofa_secret = None
    for purpose in ("login", "enable", "disable"):
        _invalidate_pending_challenges(db, current_user.id, purpose)
    db.add(current_user)
    db.commit()


@router.get("/me", response_model=MeResponse)
def read_me(current_user: User = Depends(get_current_user)) -> MeResponse:
    return MeResponse(
        user_id=current_user.id,
        email=current_user.email,
        display_name=current_user.display_name,
        twofa_enabled=current_user.twofa_enabled,
    )


@router.patch("/me", response_model=MeResponse)
def patch_me(
    payload: MePatchRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MeResponse:
    if payload.display_name is not None:
        current_user.display_name = payload.display_name.strip()

    if payload.email is not None:
        new_email = payload.email.lower()
        if new_email != current_user.email:
            if payload.current_password is None or not verify_password(
                payload.current_password, current_user.password_hash
            ):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Неверный текущий пароль",
                )
            existing = db.scalar(select(User).where(User.email == new_email))
            if existing is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Email already registered",
                )
            current_user.email = new_email

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return MeResponse(
        user_id=current_user.id,
        email=current_user.email,
        display_name=current_user.display_name,
        twofa_enabled=current_user.twofa_enabled,
    )


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
def change_password(
    payload: PasswordChangeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    if not verify_password(payload.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверный текущий пароль",
        )
    current_user.password_hash = hash_password(payload.new_password)
    db.add(current_user)
    db.commit()


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
    return RefreshResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        email=user.email,
        display_name=user.display_name,
        twofa_enabled=user.twofa_enabled,
    )
