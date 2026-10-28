"""Demo dolabı verisini sıfırlar ve zengin bir referans dolap kurar.

Kullanım (backend klasöründe, backend çalışırken):
    python scripts/seed_demo_wardrobe.py --email demo_user@example.com

Ne yapar:
1) Demo kullanıcı dolabını temizler (kıyafet + kombin + giyim geçmişi).
2) ~34 parça gerçekçi bir gardırop oluşturur (kategori + mevsim + renk;
   görsel: beyaz artalan üzerinde parça renkli şablon).
3) Son 30 gün için giyim geçmişi yazar (puanlı; parça/ikili sinyaller).
4) Amaçlara bağlı 4 kayıtlı kombin oluşturur.
"""
import argparse
import json
import urllib.parse
import urllib.request

BASE = 'http://127.0.0.1:8000'


def req(path, token=None, method=None, form=None, json_body=None):
    r = urllib.request.Request(BASE + path, method=method)
    if token:
        r.add_header('Authorization', 'Bearer ' + token)
    if form is not None:
        r.add_header('Content-Type', 'application/x-www-form-urlencoded')
        r.data = urllib.parse.urlencode(form).encode()
    if json_body is not None:
        r.add_header('Content-Type', 'application/json')
        r.data = json.dumps(json_body).encode('utf-8')
    return json.load(urllib.request.urlopen(r, timeout=60))


# ── Argüman ve kullanıcı ─────────────────────────────────────────────────────
parser = argparse.ArgumentParser()
parser.add_argument('--email', default='demo_user@example.com')
parser.add_argument('--password', default='demo1234')
args = parser.parse_args()

tok = req('/auth/login', form={
    'username': args.email, 'password': args.password})['access_token']
me = req('/auth/me', token=tok)
print(f"Kullanıcı #{me['id']} ({me['username']})")

# ── 1) Temizlik (doğrudan DB, FK sırasıyla) ─────────────────────────────────
import psycopg

conn = psycopg.connect('postgresql://dolap:dolap123@localhost:5432/dolap')
cur = conn.cursor()
with conn.transaction():
    cur.execute(
        'DELETE FROM wear_items WHERE wear_id IN '
        '(SELECT id FROM wear_history WHERE user_id = %s)', (me['id'],))
    cur.execute('DELETE FROM wear_history WHERE user_id = %s', (me['id'],))
    cur.execute(
        'DELETE FROM outfit_occasions WHERE outfit_id IN '
        '(SELECT id FROM outfits WHERE user_id = %s)', (me['id'],))
    cur.execute(
        'DELETE FROM outfit_items WHERE outfit_id IN '
        '(SELECT id FROM outfits WHERE user_id = %s)', (me['id'],))
    cur.execute('DELETE FROM outfits WHERE user_id = %s', (me['id'],))
    cur.execute('DELETE FROM clothes WHERE user_id = %s', (me['id'],))
conn.commit()
print('1) Demo dolabı temizlendi')

# ── 2) Gardırop ──────────────────────────────────────────────────────────────
# (kategori, mevsim, renk adı, hue, saturation, lightness, durum_dict)
ITEMS = [
    # Üstler
    ('tshirt', 'yaz', 'kırmızı', 2, 72, 52, {}),
    ('tshirt', 'yaz', 'sarı', 49, 90, 60, {}),
    ('tshirt', 'yaz', 'beyaz', 0, 0, 98, {}),
    ('gomlek', 'tum', 'beyaz', 0, 0, 96, {}),
    ('gomlek', 'tum', 'lacivert', 228, 58, 24, {}),
    ('kazak', 'kis', 'camel', 32, 52, 62, {}),
    ('kazak', 'kis', 'bordeaux', 350, 58, 32, {}),
    ('hoodie', 'sonbahar', 'gri', 210, 6, 62, {}),
    ('hoodie', 'sonbahar', 'hardal', 47, 85, 58, {}),
    ('bluz', 'tum', 'gül kurusu', 345, 42, 74, {}),
    ('sweatshirt', 'tum', 'lacivert', 230, 52, 28, {}),
    ('atlet', 'yaz', 'beyaz', 0, 0, 97, {}),
    # Alt
    ('pantolon', 'tum', 'siyah', 0, 0, 8, {}),
    ('pantolon', 'tum', 'bej', 40, 38, 78, {}),
    ('jean', 'tum', 'indigo', 222, 48, 38, {}),
    ('jean', 'yaz', 'açık mavi', 205, 55, 68, {}),
    ('esofman', 'sonbahar', 'gri', 210, 5, 55, {'is_dirty': True}),
    ('sort', 'yaz', 'lacivert', 228, 54, 26, {}),
    ('etek', 'ilkbahar', 'haki', 82, 30, 55, {}),
    ('etek', 'yaz', 'krem', 45, 32, 88, {}),
    # Elbise
    ('elbise', 'sonbahar', 'bordeaux', 350, 55, 32, {}),
    ('elbise', 'yaz', 'şarap', 0, 65, 40, {}),
    ('elbise', 'ilkbahar', 'mor', 280, 48, 55, {'needs_ironing': True}),
    ('tulum', 'ilkbahar', 'camel', 34, 40, 60, {}),
    # Dış
    ('ceket', 'sonbahar', 'bej', 210, 10, 70, {}),
    ('blazer', 'tum', 'lacivert', 232, 55, 22, {}),
    ('mont', 'kis', 'koyu gri', 210, 8, 22, {}),
    ('hirka', 'kis', 'camel', 34, 45, 72, {}),
    # Ayakkabı
    ('sneaker', 'tum', 'beyaz', 0, 0, 95, {}),
    ('bot', 'kis', 'kahve', 26, 48, 30, {}),
    ('sandalet', 'yaz', 'gri', 0, 0, 70, {}),
    ('topuklu', 'tum', 'siyah', 0, 0, 6, {}),
]


def make_image(color_hex: str) -> bytes:
    """Düz renk şablon görsel üretir (parça rengi neyse o görünür)."""
    from pathlib import Path

    from PIL import Image, ImageDraw
    img = Image.new('RGB', (480, 480), (255, 255, 255))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((110, 110, 370, 370), radius=40,
                        fill=tuple(int(color_hex[i:i + 2], 16)
                                   for i in (1, 3, 5)))
    out_path = Path('seed_img_tmp.png')
    img.save(out_path, 'PNG')
    return out_path.read_bytes()


import colorsys


def hsl_to_hex(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h / 360.0, l / 100.0, s / 100.0)
    return '#%02x%02x%02x' % (int(r * 255), int(g * 255), int(b * 255))


created = {}
for cat, season, cname, hue, sat, light, status in ITEMS:
    body = {
        'category': cat,
        'season': season,
        'color_name': cname,
        'hue': float(hue),
        'saturation': float(sat),
        'lightness': float(light),
    }
    body.update(status)
    item = req('/clothes/', token=tok, method='POST', json_body=body)
    # Görsel: düz renk şablon yükle (kartlar boş görünmesin)
    img = make_image(hsl_to_hex(hue, sat, light))
    boundary = '----seedboundary'
    pre = (
        f'--{boundary}\r\nContent-Disposition: form-data; '
        f'name="file"; filename="seed.png"\r\n'
        f'Content-Type: image/png\r\n\r\n'
    ).encode() + img + f'\r\n--{boundary}--\r\n'.encode()
    r = urllib.request.Request(
        BASE + f'/clothes/{item["id"]}/image', data=pre, method='POST')
    r.add_header('Authorization', 'Bearer ' + tok)
    r.add_header('Content-Type',
                 f'multipart/form-data; boundary={boundary}')
    urllib.request.urlopen(r, timeout=60)
    created.setdefault(cat, []).append(item['id'])
conn.close()
Path('seed_img_tmp.png').unlink(missing_ok=True)
print(f'2) {len(ITEMS)} parça eklendi (görselleriyle)')


def pick(cat, which=0):
    return created[cat][which]


# ── 3) Amaç grupları ─────────────────────────────────────────────────────────
groups = req('/occasions/', token=tok)
gid = {g['name']: g['id'] for g in groups}
print('3) Amaç grupları:', {k: v for k, v in gid.items() if v})


def occasion_id(name):
    return gid.get(name)


# ── 4) Giyim geçmişi (son 30 gün) ────────────────────────────────────────────
# (parçalar, amaç, puan)
from datetime import datetime, timedelta, timezone

now = datetime.now(timezone.utc)
WEARS = [
    ([pick('tshirt', 0), pick('pantolon', 0), pick('sneaker', 0)],
     'Özel gün', 5, 27),
    ([pick('gomlek', 0), pick('jean', 0), pick('sneaker', 0)],
     'Okul', 4, 24),
    ([pick('sweatshirt', 0), pick('esofman', 0), pick('sneaker', 0)],
     'Spor', 3, 19),
    ([pick('blazer', 0), pick('pantolon', 0), pick('topuklu', 0)],
     'İş', 5, 16),
    ([pick('elbise', 1), pick('sandalet', 0)],
     'Arkadaş', 4, 12),
    ([pick('kazak', 0), pick('jean', 0), pick('bot', 0)],
     'Günlük', 4, 8),
    ([pick('hoodie', 0), pick('jean', 0), pick('sneaker', 0)],
     'Günlük', 5, 5),
    ([pick('bluz', 0), pick('etek', 0), pick('topuklu', 0)],
     'Özel gün', 4, 2),
]
for clothes_ids, occ, rating, days_ago in WEARS:
    wear = {
        'clothing_ids': clothes_ids,
        'rating': rating,
        'worn_at': (now - timedelta(days=days_ago)).isoformat(),
    }
    oid = occasion_id(occ)
    if oid:
        wear['occasion_group_id'] = oid
    req('/wear/', token=tok, method='POST', json_body=wear)
print(f'4) {len(WEARS)} giyim kaydı eklendi (puanlı, son 30 gün)')

# ── 5) Kayıtlı kombinler ─────────────────────────────────────────────────────
OUTFITS = [
    ([pick('gomlek', 0), pick('pantolon', 0), pick('sneaker', 0)],
     ['Okul']),
    ([pick('blazer', 0), pick('pantolon', 0), pick('topuklu', 0)],
     ['İş', 'Özel gün']),
    ([pick('elbise', 1), pick('sandalet', 0)], ['Arkadaş']),
    ([pick('kazak', 1), pick('jean', 0), pick('bot', 0)], ['Günlük']),
]
for clothes_ids, occ_names in OUTFITS:
    ids = [occasion_id(n) for n in occ_names if occasion_id(n)]
    req('/outfits/', token=tok, method='POST', json_body={
        'clothing_ids': clothes_ids,
        'is_favorite': False,
        'occasion_ids': ids,
    })
print(f'5) {len(OUTFITS)} kayıtlı kombin eklendi')

# ── 6) Kalite kontrolü ───────────────────────────────────────────────────────
print('\n— Öneri kalitesi kontrolü —')
for label, suffix in [
    ('Kırmızı üst + siyah pantolon kolaylığı (Tümü)', ''),
    ('Amaç: İş', '?occasion_id=' + str(occasion_id('İş'))),
    ('Amaç: Özel gün', '?occasion_id=' + str(occasion_id('Özel gün'))),
    ('Hava (Ankara) + İş', '?occasion_id=' + str(occasion_id('İş'))
     + '&lat=39.9334&lon=32.8597&city=Ankara'),
]:
    s = req('/outfits/suggest' + suffix, token=tok)
    best = s[0] if s else None
    if best:
        print(f'{label}: skor {best["score"]:.3f} — {best["reasons"]}')
    else:
        print(f'{label}: (öneri üretilmedi)')
printed = req('/events/insights?window_days=30', token=tok)
_ = printed
print('Tohumlama bitti.')
