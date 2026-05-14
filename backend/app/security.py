"""Хэширование и проверка паролей (алгоритм bcrypt — стандарт для хранения паролей в базе)."""

from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """Превращает пароль в безопасную строку для записи в базу (в открытом виде пароль не храним)."""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Сравнивает введённый пароль с тем, что лежит в базе после хэширования."""
    return pwd_context.verify(plain_password, hashed_password)
