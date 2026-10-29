"""Kullanıcı adı/şifre doğrulama kuralları (register ve change-password
aynı kuralları paylaşır; uçtan uca tutarlılık için tek yerde)."""
import re

USERNAME_RE = re.compile(r"^[A-Za-z0-9_.\-]+$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

MIN_PASSWORD_LEN = 6
MIN_USERNAME_LEN = 3
MAX_USERNAME_LEN = 30


def validate_password(password: str) -> str | None:
    """Şifre geçersizse Türkçe hata metni döner; geçerliyse None."""
    if not password or len(password) < MIN_PASSWORD_LEN:
        return f"Şifre en az {MIN_PASSWORD_LEN} karakter olmalı"
    if len(password) > 128:
        return "Şifre en fazla 128 karakter olabilir"
    if len(password.strip()) != len(password):
        return "Şifre başında/sonunda boşluk içeremez"
    return None


def validate_username(username: str) -> str | None:
    """Kullanıcı adı geçersizse Türkçe hata metni döner; geçerliyse None."""
    name = (username or "").strip()
    if len(name) < MIN_USERNAME_LEN:
        return f"Kullanıcı adı en az {MIN_USERNAME_LEN} karakter olmalı"
    if len(name) > MAX_USERNAME_LEN:
        return f"Kullanıcı adı en fazla {MAX_USERNAME_LEN} karakter olabilir"
    if not USERNAME_RE.match(name):
        return "Kullanıcı adı yalnızca harf, rakam, nokta, alt çizgi ve tire içerebilir"
    return None


def normalize_email(email: str) -> str:
    """E-postayı küçük harfe indirger (login/register tutarlılığı)."""
    return (email or "").strip().lower()
