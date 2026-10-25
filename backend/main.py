import os

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from database import engine
from models import clothing, occasion, outfit, user
from routers.auth_router import router as auth_router
from routers.clothing_router import router as clothing_router
from routers.occasion_router import router as occasion_router
from routers.outfit_router import router as outfit_router
from routers.wear_router import router as wear_router

app = FastAPI(title="Dijital Dolap API")

# Statik dosya yolu — görseller buradan servis edilir
uploads_dir = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(uploads_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=uploads_dir), name="uploads")

app.include_router(auth_router)
app.include_router(clothing_router)
app.include_router(outfit_router)
app.include_router(wear_router)
app.include_router(occasion_router)


@app.get("/")
def root():
    return {"message": "Merhaba, Dijital Dolap!"}


@app.get("/health")
def health():
    """Basit sağlık kontrolü (dış izleyiciler ve dağıtım için)."""
    return {"status": "ok"}


@app.get("/db-test")
def db_test():
    with engine.connect() as conn:
        result = conn.execute(text("SELECT version()"))
        return {"postgres": result.scalar()}
