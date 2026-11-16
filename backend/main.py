import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from database import engine
from models import calendar_event, clothing, occasion, outfit, user
from routers.auth_router import router as auth_router
from routers.clothing_router import router as clothing_router
from routers.event_router import router as event_router
from routers.insights_router import router as insights_router
from routers.occasion_router import router as occasion_router
from routers.settings_router import router as settings_router
from routers.outfit_router import router as outfit_router
from routers.weather_router import router as weather_router
from routers.wear_router import router as wear_router

app = FastAPI(title="Dijital Dolap API")

# Web (Flutter web) ön yüzünün ayrı bir porttandan API'yi çağırabilmesi için.
# Geliştirme ortamında yerel kaynaklara izin verilir.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:37498", "http://127.0.0.1:37498"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Statik dosya yolu — görseller buradan servis edilir
uploads_dir = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(uploads_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=uploads_dir), name="uploads")

app.include_router(auth_router)
app.include_router(clothing_router)
app.include_router(outfit_router)
app.include_router(wear_router)
app.include_router(occasion_router)
app.include_router(weather_router)
app.include_router(event_router)
app.include_router(insights_router)
app.include_router(settings_router)


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
