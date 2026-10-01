from fastapi import FastAPI
from sqlalchemy import text
from database import engine
from models import user, clothing, outfit
from routers.auth_router import router as auth_router
from routers.clothing_router import router as clothing_router

app = FastAPI(title="Dijital Dolap API")

app.include_router(auth_router)
app.include_router(clothing_router)

@app.get("/")
def root():
    return {"message": "Merhaba, Dijital Dolap!"}

@app.get("/db-test")
def db_test():
    with engine.connect() as conn:
        result = conn.execute(text("SELECT version()"))
        return {"postgres": result.scalar()}