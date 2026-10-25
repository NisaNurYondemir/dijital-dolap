"""Uçtan uca duman testi (canlı backend'e karşı).

Analiz -> önizleme -> kaydet (201) -> aynı geçici görsel (410) ->
geçersiz ad (400) -> oku -> sil (204) akışını doğrular.

Kullanım (backend klasöründe, backend çalışırken):
    python scripts/e2e_smoke_test.py
    python scripts/e2e_smoke_test.py --cleanup-user   # test kullanıcısını da siler

--cleanup-user, yerel geliştirme Docker konteynerini (dolap_db) kullanır.
"""
import argparse
import subprocess
import sys
import time

import requests

DB_CONTAINER = "dolap_db"
DB_USER = "dolap"
DB_NAME = "dolap"


class Checks:
    def __init__(self) -> None:
        self.results: list[tuple[str, bool, str]] = []

    def add(self, name: str, ok: bool, detail: str = "") -> None:
        self.results.append((name, ok, detail))
        mark = "OK  " if ok else "FAIL"
        print(f"{mark} {name}" + (f"  ({detail})" if detail else ""), flush=True)

    def summary(self) -> int:
        failed = [r for r in self.results if not r[1]]
        print(f"\n{len(self.results) - len(failed)}/{len(self.results)} kontrol geçti")
        return 1 if failed else 0


def cleanup_user(user_id: int) -> None:
    sql = f"DELETE FROM users WHERE id = {user_id} AND username LIKE 'e2e_%';"
    subprocess.run(
        ["docker", "exec", DB_CONTAINER, "psql", "-U", DB_USER, "-d", DB_NAME, "-c", sql],
        check=False,
        capture_output=True,
        text=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Dijital Dolap uçtan uca duman testi")
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--image", default="test_clothing.jpg")
    parser.add_argument("--cleanup-user", action="store_true",
                        help="Test sonunda oluşturulan kullanıcıyı da sil")
    args = parser.parse_args()

    base = args.base_url.rstrip("/")
    stamp = int(time.time())
    email = f"e2e_{stamp}@example.com"
    username = f"e2e_{stamp}"
    password = "Test1234!"

    c = Checks()
    user_id = None

    try:
        r = requests.post(f"{base}/auth/register", timeout=60,
                          json={"email": email, "username": username, "password": password})
        c.add("register 201", r.status_code == 201, str(r.status_code))
        user_id = r.json().get("id")

        r = requests.post(f"{base}/auth/login", timeout=60,
                          data={"username": email, "password": password})
        c.add("login 200", r.status_code == 200, str(r.status_code))
        token = r.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        with open(args.image, "rb") as f:
            r = requests.post(f"{base}/clothes/analyze", headers=headers, timeout=180,
                              files={"file": (args.image, f, "image/jpeg")})
        c.add("analyze 200", r.status_code == 200, str(r.status_code))
        analysis = r.json()
        temp = analysis["temp_image"]
        c.add("analyze kategori döndü", bool(analysis.get("category")),
              str(analysis.get("category")))
        c.add("analyze 3 aday döndü", len(analysis.get("category_candidates", [])) == 3)

        r = requests.get(f"{base}/uploads/tmp/{temp}", timeout=30)
        c.add("önizleme 200", r.status_code == 200, f"{len(r.content)} bayt")

        body = {
            "category": analysis["category"],
            "season": analysis["season"],
            "color_name": analysis.get("color_name"),
            "hue": analysis.get("hue"),
            "saturation": analysis.get("saturation"),
            "lightness": analysis.get("lightness"),
            "is_dirty": False,
            "needs_ironing": False,
            "is_ironed": False,
            "temp_image": temp,
        }
        r = requests.post(f"{base}/clothes/", headers=headers, json=body, timeout=60)
        c.add("kaydet 201", r.status_code == 201, str(r.status_code))
        item_id = r.json().get("id")
        c.add("görsel kalıcı klasöre taşındı", bool(r.json().get("image_path")))

        r = requests.post(f"{base}/clothes/", headers=headers, json=body, timeout=60)
        c.add("aynı temp_image 410", r.status_code == 410, str(r.status_code))

        r = requests.post(f"{base}/clothes/", headers=headers,
                          json=dict(body, temp_image="999_deadbeef.png"), timeout=60)
        c.add("geçersiz ad 400", r.status_code == 400, str(r.status_code))

        r = requests.get(f"{base}/clothes/{item_id}", headers=headers, timeout=30)
        c.add("kaydı oku 200", r.status_code == 200, str(r.status_code))

        r = requests.delete(f"{base}/clothes/{item_id}", headers=headers, timeout=30)
        c.add("kaydı sil 204", r.status_code == 204, str(r.status_code))
    except requests.RequestException as exc:
        c.add("bağlantı", False, str(exc))
    finally:
        if args.cleanup_user and user_id is not None:
            cleanup_user(user_id)
            print(f"test kullanıcısı silindi (id={user_id})")

    return c.summary()


if __name__ == "__main__":
    sys.exit(main())
