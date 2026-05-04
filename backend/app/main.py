from fastapi import FastAPI
from sqlalchemy import text

from app.api import auth_router
from app.db import SessionLocal

app = FastAPI(title="MediaLib API", version="0.1.0")
app.include_router(auth_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/health/db")
def health_db() -> dict[str, str]:
    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
        return {"status": "ok"}
    except Exception:
        return {"status": "error"}
