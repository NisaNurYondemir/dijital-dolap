from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr

from auth import get_db, hash_password, verify_password, create_access_token, get_current_user
from auth_validation import (
    MIN_PASSWORD_LEN,
    normalize_email,
    validate_password,
    validate_username,
)
from models.user import User
from rate_limit import RateLimiter

router = APIRouter(prefix="/auth", tags=["auth"])

# Login brute-force koruması: 15 dk içinde 5 hatalı deneme -> kilit.
_login_limiter = RateLimiter(max_attempts=5, window_seconds=900)


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"

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
    error = validate_password(req.new_password)
    if error:
        raise HTTPException(400, error)
    if verify_password(req.new_password, current_user.hashed_password):
        raise HTTPException(400, "Yeni şifre mevcut şifreyle aynı olamaz")
    current_user.hashed_password = hash_password(req.new_password)
    db.commit()
    return {"message": "Şifre başarıyla değiştirildi"}
# --- Endpoint'ler ---
@router.post("/register", status_code=201)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    email = normalize_email(req.email)
    username = (req.username or "").strip()

    error = validate_username(username)
    if error:
        raise HTTPException(400, error)
    error = validate_password(req.password)
    if error:
        raise HTTPException(400, error)

    if db.query(User).filter(User.email == email).first():
        raise HTTPException(400, "Bu e-posta zaten kayıtlı")
    if db.query(User).filter(User.username == username).first():
        raise HTTPException(400, "Bu kullanıcı adı zaten alınmış")

    user = User(
        email=email,
        username=username,
        hashed_password=hash_password(req.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"id": user.id, "username": user.username, "email": user.email}

@router.post("/login", response_model=TokenResponse)
def login(
    request: Request,
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    email = normalize_email(form.username)
    key = f"{_client_ip(request)}:{email}"

    remaining = _login_limiter.blocked_for(key)
    if remaining is not None:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Çok fazla hatalı deneme. Lütfen birkaç dakika sonra tekrar dene.",
        )

    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(form.password, user.hashed_password):
        _login_limiter.hit(key)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "E-posta veya şifre hatalı")

    _login_limiter.reset(key)
    token = create_access_token({"sub": str(user.id)})
    return {"access_token": token}

@router.get("/me")
def me(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "username": current_user.username,
        "email": current_user.email,
    }
