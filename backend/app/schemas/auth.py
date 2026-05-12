from uuid import UUID

from pydantic import BaseModel, EmailStr, Field, model_validator


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
    email: EmailStr | None = None
    display_name: str | None = None


class RefreshRequest(BaseModel):
    refresh_token: str


class RefreshResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    email: EmailStr | None = None
    display_name: str | None = None


class MeResponse(BaseModel):
    user_id: UUID
    email: EmailStr
    display_name: str


class MePatchRequest(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=120)
    email: EmailStr | None = None
    current_password: str | None = Field(default=None, min_length=8, max_length=128)

    @model_validator(mode="after")
    def validate_patch(self) -> MePatchRequest:
        if self.display_name is None and self.email is None:
            raise ValueError("Укажите новое имя или email")
        return self


class PasswordChangeRequest(BaseModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class TwoFASetupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class TwoFASetupResponse(BaseModel):
    secret: str
    otp_auth_uri: str


class TwoFAVerifyRequest(BaseModel):
    challenge_token: str
    otp_code: str = Field(min_length=6, max_length=8)
