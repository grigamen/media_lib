from pydantic_settings import BaseSettings, SettingsConfigDict

# Полный список типов, которые может отправить мобильное приложение. Используется
# в API как нижняя граница: к ALLOWED_UPLOAD_CONTENT_TYPES из env добавляется union,
# чтобы урезанный production-.env не ломал загрузку (например MKV / Matroska).
DEFAULT_ALLOWED_UPLOAD_CONTENT_TYPES: str = (
    "audio/mpeg,audio/mp4,audio/aac,audio/wav,audio/ogg,"
    "video/mp4,video/webm,video/x-msvideo,video/avi,"
    "video/x-matroska,video/mkv,video/quicktime,text/plain,text/markdown,application/pdf,"
    "application/epub+zip,application/vnd.openxmlformats-officedocument."
    "wordprocessingml.document,image/jpeg,image/png,image/webp"
)


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
    #: Для presigned GET/PUT: базовый URL, с которого клиенты (телефоны) достучатся до S3/MinIO.
    #: Если не задан, используется S3_ENDPOINT_URL (на ВМ с MinIO на localhost телефоны не откроют файл).
    S3_PUBLIC_ENDPOINT_URL: str | None = None
    AWS_ACCESS_KEY_ID: str = "test-access-key"
    AWS_SECRET_ACCESS_KEY: str = "test-secret-key"
    S3_PRESIGNED_EXPIRES_SEC: int = 900
    MAX_UPLOAD_FILE_SIZE_BYTES: int = 2147483648
    ALLOWED_UPLOAD_CONTENT_TYPES: str = DEFAULT_ALLOWED_UPLOAD_CONTENT_TYPES
    #: If False, POST /media-files/{id}/complete skips head_object size check (tests patch
    #: this call; disable only for local debugging when storage is unreachable).
    VERIFY_UPLOAD_OBJECT_IN_STORAGE: bool = True


settings = Settings()
