from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from auth import get_db, hash_password, verify_password, create_access_token, get_current_user
from models.user import User

router = APIRouter(prefix="/auth", tags=["auth"])

# --- Şemalar ---
class RegisterRequest(BaseModel):
    email: EmailStr
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

@router.post("/change-password", status_code=200)
def change_password(
    req: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not verify_password(req.current_password, current_user.hashed_password):
        raise HTTPException(400, "Mevcut şifre hatalı")
    if len(req.new_password) < 6:
        raise HTTPException(400, "Yeni şifre en az 6 karakter olmalı")
    if verify_password(req.new_password, current_user.hashed_password):
        raise HTTPException(400, "Yeni şifre mevcut şifreyle aynı olamaz")
    current_user.hashed_password = hash_password(req.new_password)
    db.commit()
    return {"message": "Şifre başarıyla değiştirildi"}
# --- Endpoint'ler ---
@router.post("/register", status_code=201)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == req.email).first():
        raise HTTPException(400, "Bu e-posta zaten kayıtlı")
    if db.query(User).filter(User.username == req.username).first():
        raise HTTPException(400, "Bu kullanıcı adı zaten alınmış")

    user = User(
        email=req.email,
        username=req.username,
        hashed_password=hash_password(req.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"id": user.id, "username": user.username, "email": user.email}

@router.post("/login", response_model=TokenResponse)
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == form.username).first()
    if not user or not verify_password(form.password, user.hashed_password):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "E-posta veya şifre hatalı")

    token = create_access_token({"sub": str(user.id)})
    return {"access_token": token}

@router.get("/me")
def me(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "username": current_user.username,
        "email": current_user.email,
    }