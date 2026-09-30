from fastapi import FastAPI
from sqlalchemy import text
from database import engine

app = FastAPI(title="Dijital Dolap API")

@app.get("/")
def root():
    return {"message": "Merhaba, Dijital Dolap!"}

@app.get("/db-test")
def db_test():
    with engine.connect() as conn:
        result = conn.execute(text("SELECT version()"))
        return {"postgres": result.scalar()}