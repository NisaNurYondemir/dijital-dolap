from fastapi import FastAPI

app = FastAPI(title="Dijital Dolap API")

@app.get("/")
def root():
    return {"message": "Merhaba, Dijital Dolap!"}