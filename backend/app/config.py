from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    DATABASE_URL: str
    JWT_SECRET: str
    JWT_ALG: str = "HS256"
    ACCESS_TOKEN_MIN: int = 30
    REFRESH_TOKEN_DAYS: int = 7
    TWOFA_CHALLENGE_MIN: int = 5
    S3_BUCKET: str = "medialib-dev"
    S3_REGION: str = "us-east-1"
    S3_ENDPOINT_URL: str | None = None
    AWS_ACCESS_KEY_ID: str = "test-access-key"
    AWS_SECRET_ACCESS_KEY: str = "test-secret-key"
    S3_PRESIGNED_EXPIRES_SEC: int = 900
    MAX_UPLOAD_FILE_SIZE_BYTES: int = 524288000
    ALLOWED_UPLOAD_CONTENT_TYPES: str = "audio/mpeg,audio/mp4,video/mp4,video/webm"


settings = Settings()
