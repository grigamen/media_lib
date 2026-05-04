from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=120)


class RegisterResponse(BaseModel):
    user_id: UUID
    email: EmailStr
    display_name: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class LoginResponse(BaseModel):
    access_token: str | None = None
    refresh_token: str | None = None
    challenge_token: str | None = None
    token_type: str = "bearer"
    requires_2fa: bool = False


class RefreshRequest(BaseModel):
    refresh_token: str


class RefreshResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TwoFASetupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class TwoFASetupResponse(BaseModel):
    secret: str
    otp_auth_uri: str


class TwoFAVerifyRequest(BaseModel):
    challenge_token: str
    otp_code: str = Field(min_length=6, max_length=8)
