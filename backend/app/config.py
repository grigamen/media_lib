from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    DATABASE_URL: str
    JWT_SECRET: str
    JWT_ALG: str = "HS256"
    ACCESS_TOKEN_MIN: int = 30
    REFRESH_TOKEN_DAYS: int = 7
    TWOFA_CHALLENGE_MIN: int = 5


settings = Settings()
