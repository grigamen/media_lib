from pydantic_settings import BaseSettings, SettingsConfigDict

# Разрешённые типы файлов при загрузке с телефона (список через запятую в настройках).
# Сюда же подмешивается полный набор по умолчанию: даже если в .env указали мало типов,
# редкие форматы вроде mkv не пропадут из белого списка без явного желания.
DEFAULT_ALLOWED_UPLOAD_CONTENT_TYPES: str = (
    "audio/mpeg,audio/mp4,audio/aac,audio/wav,audio/ogg,"
    "video/mp4,video/webm,video/x-msvideo,video/avi,"
    "video/x-matroska,video/mkv,video/quicktime,text/plain,text/markdown,application/pdf,"
    "application/epub+zip,application/vnd.openxmlformats-officedocument."
    "wordprocessingml.document,image/jpeg,image/png,image/webp"
)


class Settings(BaseSettings):
    """Все секреты и параметры читаются из переменных окружения и при необходимости из файла .env рядом с приложением."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    DATABASE_URL: str  # строка подключения к Postgres
    JWT_SECRET: str  # общий секрет для подписи токенов входа (должен быть длинным и не светиться в git)
    JWT_ALG: str = "HS256"  # алгоритм подписи JWT
    ACCESS_TOKEN_MIN: int = 30  # сколько минут живёт «рабочий» токен на запросы
    REFRESH_TOKEN_DAYS: int = 7  # сколько дней можно обновлять сессию без повторного пароля
    TWOFA_CHALLENGE_MIN: int = 5  # срок временного токена между паролем и кодом из почты
    TWOFA_CODE_LENGTH: int = 6  # сколько цифр в коде из письма
    TWOFA_OTP_PEPPER: str = ""  # доп. секрет только для кодов 2FA; пусто — берётся JWT_SECRET
    TWOFA_CODE_TTL_MIN: int = 10  # через сколько минут код из письма перестаёт действовать
    TWOFA_MAX_ATTEMPTS: int = 5  # сколько раз подряд можно ошибиться вводом кода
    TWOFA_RESEND_COOLDOWN_SEC: int = 60  # минимальный интервал «отправить код ещё раз»
    MAIL_MODE: str = "console"  # как слать почту: smtp | console (только в консоль) | none (не слать)
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_USE_TLS: bool = True
    MAIL_FROM: str = ""  # адрес «от кого» в письмах
    S3_BUCKET: str = "medialib-dev"  # корзина в S3-совместимом хранилище
    S3_REGION: str = "us-east-1"
    S3_ENDPOINT_URL: str | None = None  # для MinIO и т.п. — свой URL вместо Amazon
    S3_PUBLIC_ENDPOINT_URL: str | None = None  # адрес, с которого телефон реально качает файлы (часто не localhost)
    AWS_ACCESS_KEY_ID: str = "test-access-key"
    AWS_SECRET_ACCESS_KEY: str = "test-secret-key"
    S3_PRESIGNED_EXPIRES_SEC: int = 900  # через сколько секунд одноразовые ссылки на заливку/скачивание истекают
    MAX_UPLOAD_FILE_SIZE_BYTES: int = 2147483648  # максимальный размер одного файла (байты)
    ALLOWED_UPLOAD_CONTENT_TYPES: str = DEFAULT_ALLOWED_UPLOAD_CONTENT_TYPES  # допустимые типы контента при загрузке
    VERIFY_UPLOAD_OBJECT_IN_STORAGE: bool = True  # после заливки проверять, что объект реально появился в хранилище


settings = Settings()
