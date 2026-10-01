from fastapi import FastAPI
from sqlalchemy import text
from database import engine
from models import user, clothing, outfit   # ← bunu ekle
from routers.auth_router import router as auth_router

app = FastAPI(title="Dijital Dolap API")

app.include_router(auth_router)

@app.get("/")
def root():
    return {"message": "Merhaba, Dijital Dolap!"}

@app.get("/db-test")
def db_test():
    with engine.connect() as conn:
        result = conn.execute(text("SELECT version()"))
        return {"postgres": result.scalar()}