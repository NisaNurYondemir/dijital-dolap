from auth_validation import (
    normalize_email,
    validate_password,
    validate_username,
)


def test_password_min_length():
    assert validate_password("12345") == "Şifre en az 6 karakter olmalı"
    assert validate_password("") == "Şifre en az 6 karakter olmalı"
    assert validate_password("123456") is None
    assert validate_password("cok-gizli-sifrem") is None


def test_password_too_long_and_spaces():
    assert validate_password("x" * 129) == "Şifre en fazla 128 karakter olabilir"
    assert validate_password(" sifre ") == "Şifre başında/sonunda boşluk içeremez"


def test_username_charset_and_length():
    assert validate_username("ab") == "Kullanıcı adı en az 3 karakter olmalı"
    assert validate_username("a" * 31) == "Kullanıcı adı en fazla 30 karakter olabilir"
    assert validate_username("kötü ad!") == (
        "Kullanıcı adı yalnızca harf, rakam, nokta, alt çizgi ve tire içerebilir"
    )
    assert validate_username("demouser") is None
    assert validate_username("demo_user-1") is None
    assert validate_username("yerdegil  bosluk") is not None


def test_email_is_normalized():
    assert normalize_email("  Demo@EXAMPLE.com ") == "demo@example.com"
    assert normalize_email("") == ""
