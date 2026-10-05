#!/usr/bin/env python3
"""Fill a Tracqer API with a demo collection.

Creates about twenty records with plain generated placeholder photos (coloured
sleeves with the title printed on them and simple disc labels; no real cover
art). Everything goes through the normal encrypted API, so the server, the
password and the photo pipeline are all exercised exactly as a client would.

    python scripts/seed_demo.py --url http://localhost:8000 --password changeme

By default it refuses to touch a server that already has records. Pass
--force to add the demo records anyway.

Needs only the API's own requirements (cryptography and Pillow).
"""

from __future__ import annotations

import argparse
import colorsys
import io
import json
import sys
import textwrap
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from api.crypto import decrypt, derive_token, encrypt, init_key  # noqa: E402

# ---------------------------------------------------------------------------
# Demo collection
# ---------------------------------------------------------------------------
# photos: which slots get a generated placeholder image.
#   "front", "back", "gatefold", "inner" (paper inner sleeve), "discs"

DEMO_RECORDS: list[dict] = [
    dict(artist="Pink Floyd", title="The Dark Side of the Moon", year=1973, label="Harvest",
         genre="Progressive Rock", duration="42:49", format='12" LP', speed="33", owner="dad",
         disc_condition="VG+", sleeve_condition="VG", hue=0.62,
         notes="Original UK pressing with both posters and the stickers.",
         photos=["front", "back", "gatefold", "inner", "discs"]),
    dict(artist="Fleetwood Mac", title="Rumours", year=1977, label="Warner Bros.",
         genre="Rock", duration="39:43", format='12" LP', speed="33", owner="shared",
         disc_condition="VG+", sleeve_condition="VG+", hue=0.08, photos=["front", "back", "discs"]),
    dict(artist="Miles Davis", title="Kind of Blue", year=1959, label="Columbia",
         genre="Jazz", duration="45:44", format='12" LP', speed="33", owner="dad",
         disc_condition="VG", sleeve_condition="G+", hue=0.55,
         notes="Six-eye label. Light ring wear on the sleeve.", photos=["front", "discs"]),
    dict(artist="Kate Bush", title="Hounds of Love", year=1985, label="EMI",
         genre="Art Pop", duration="47:31", format='12" LP', speed="33", owner="me",
         disc_condition="NM", sleeve_condition="NM", hue=0.75, photos=["front", "back", "inner"]),
    dict(artist="Joy Division", title="Unknown Pleasures", year=1979, label="Factory",
         genre="Post-Punk", duration="39:24", format='12" LP', speed="33", owner="me",
         disc_condition="VG+", sleeve_condition="VG", hue=0.0, sat=0.0, photos=["front", "discs"]),
    dict(artist="The Beatles", title="Abbey Road", year=1969, label="Apple",
         genre="Rock", duration="47:03", format='12" LP', speed="33", owner="dad",
         disc_condition="VG", sleeve_condition="G+", hue=0.33, photos=["front", "back"]),
    dict(artist="Radiohead", title="OK Computer", year=1997, label="Parlophone",
         genre="Alternative Rock", duration="53:21", format='12" LP', speed="33", owner="me",
         disc_count=2, disc_condition="NM", sleeve_condition="NM", hue=0.52,
         notes="2xLP, gatefold.", photos=["front", "gatefold", "discs"]),
    dict(artist="Daft Punk", title="Discovery", year=2001, label="Virgin",
         genre="House", duration="60:50", format='12" LP', speed="33", owner="me",
         disc_count=2, disc_condition="VG+", sleeve_condition="VG+", hue=0.95, photos=["front"]),
    dict(artist="New Order", title="Blue Monday", year=1983, label="Factory",
         genre="Synth-pop", duration="7:29", format='12" single', speed="45", owner="me",
         outer_sleeve_only=True, disc_condition="VG+", sleeve_condition="VG", hue=0.6,
         photos=["front", "discs"]),
    dict(artist="The Smiths", title="This Charming Man", year=1983, label="Rough Trade",
         genre="Indie", duration="2:41", format='7" single', speed="45", owner="shared",
         outer_sleeve_only=True, disc_condition="VG", sleeve_condition="VG", hue=0.45,
         photos=["front", "discs"]),
    dict(artist="David Bowie", title="Hunky Dory", year=1971, label="RCA Victor",
         genre="Rock", duration="41:50", format='12" LP', speed="33", owner="dad",
         disc_condition="VG", sleeve_condition="VG", hue=0.13, photos=["front", "back"]),
    dict(artist="Massive Attack", title="Blue Lines", year=1991, label="Wild Bunch",
         genre="Trip Hop", duration="45:01", format='12" LP', speed="33", owner="shared",
         disc_condition="NM", sleeve_condition="VG+", hue=0.02, photos=["front"]),
    dict(artist="Stevie Wonder", title="Songs in the Key of Life", year=1976, label="Tamla",
         genre="Soul", duration="104:30", format='12" LP', speed="33", owner="dad",
         disc_count=2, disc_condition="VG", sleeve_condition="G+", hue=0.07,
         notes="Bonus 7-inch EP and lyric booklet are missing.", photos=["front", "discs"]),
    dict(artist="Elvis Presley", title="Heartbreak Hotel", year=1956, label="HMV",
         genre="Rock and Roll", duration="2:08", format="Other", speed="78", owner="dad",
         outer_sleeve_only=True, disc_condition="G", sleeve_condition="F", hue=0.1, sat=0.25,
         notes="10-inch shellac 78 in a plain company sleeve.", photos=["discs"]),
    dict(artist="Arctic Monkeys", title="Whatever People Say I Am, That's What I'm Not",
         year=2006, label="Domino", genre="Indie Rock", duration="41:00", format='12" LP',
         speed="33", owner="me", disc_condition="NM", sleeve_condition="NM", hue=0.58,
         photos=["front"]),
    dict(artist="Nina Simone", title="Wild Is the Wind", year=1966, label="Philips",
         genre="Jazz", duration="35:20", format='12" LP', speed="33", owner="dad",
         disc_condition="VG", sleeve_condition="VG", hue=0.9, photos=[]),
    dict(artist="Portishead", title="Dummy", year=1994, label="Go! Beat",
         genre="Trip Hop", duration="49:17", format='12" LP', speed="33", owner="shared",
         disc_condition="VG+", sleeve_condition="VG+", hue=0.48, photos=["front", "back"]),
    dict(artist="Blondie", title="Heart of Glass", year=1979, label="Chrysalis",
         genre="New Wave", duration="3:54", format='7" single', speed="45", owner="me",
         outer_sleeve_only=True, disc_condition="VG+", sleeve_condition="VG", hue=0.85,
         photos=["front"]),
    dict(artist="Talking Heads", title="Remain in Light", year=1980, label="Sire",
         genre="New Wave", duration="40:07", format='12" LP', speed="33", owner="shared",
         disc_condition="VG+", sleeve_condition="VG", hue=0.98, photos=[]),
    dict(artist="Ella Fitzgerald", title="Ella in Berlin", year=1960, label="Verve",
         genre="Jazz", duration="36:52", format='10" LP', speed="33", owner="dad",
         disc_condition="VG", sleeve_condition="G+", hue=0.15, photos=["front"]),
]

# ---------------------------------------------------------------------------
# Placeholder artwork
# ---------------------------------------------------------------------------

_FONT_CANDIDATES = [
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/System/Library/Fonts/Helvetica.ttc",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
]


def _font(size: int) -> ImageFont.ImageFont:
    for path in _FONT_CANDIDATES:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # Pillow < 10.1
        return ImageFont.load_default()


def _rgb(hue: float, sat: float, light: float) -> tuple[int, int, int]:
    r, g, b = colorsys.hls_to_rgb(hue % 1.0, light, sat)
    return int(r * 255), int(g * 255), int(b * 255)


def _jpeg(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.convert("RGB").save(buf, format="JPEG", quality=88)
    return buf.getvalue()


def _wrapped(draw: ImageDraw.ImageDraw, xy, text, font, fill, width_chars, spacing=10):
    lines = textwrap.wrap(text, width=width_chars) or [text]
    draw.multiline_text(xy, "\n".join(lines), font=font, fill=fill, spacing=spacing)
    return len(lines)


def sleeve_front(rec: dict, size: int = 1000) -> bytes:
    sat = rec.get("sat", 0.45)
    bg = _rgb(rec["hue"], sat, 0.32)
    band = _rgb(rec["hue"], sat, 0.55)
    img = Image.new("RGB", (size, size), bg)
    d = ImageDraw.Draw(img)
    d.rectangle([0, int(size * 0.66), size, int(size * 0.70)], fill=band)
    m = int(size * 0.08)
    d.text((m, m), rec["artist"].upper(), font=_font(int(size * 0.045)), fill=(240, 236, 228))
    _wrapped(d, (m, int(size * 0.74)), rec["title"], _font(int(size * 0.075)),
             (250, 248, 244), width_chars=20)
    d.text((size - m, m), str(rec.get("year", "")), font=_font(int(size * 0.04)),
           fill=(240, 236, 228), anchor="ra")
    return _jpeg(img)


def sleeve_back(rec: dict, size: int = 1000) -> bytes:
    bg = _rgb(rec["hue"], 0.15, 0.9)
    ink = _rgb(rec["hue"], 0.4, 0.22)
    img = Image.new("RGB", (size, size), bg)
    d = ImageDraw.Draw(img)
    m = int(size * 0.08)
    d.text((m, m), f"{rec['artist']}  /  {rec['title']}", font=_font(int(size * 0.035)), fill=ink)
    y = int(size * 0.2)
    small = _font(int(size * 0.03))
    for side in ("Side A", "Side B"):
        d.text((m, y), side, font=_font(int(size * 0.035)), fill=ink)
        y += int(size * 0.06)
        for n in range(1, 5):
            d.line([m, y + 14, size - m, y + 14], fill=_rgb(rec["hue"], 0.15, 0.78), width=2)
            d.text((m, y - 6), f"{n}.", font=small, fill=ink)
            y += int(size * 0.055)
        y += int(size * 0.04)
    d.text((m, size - m), f"{rec.get('label', '')}  {rec.get('year', '')}",
           font=small, fill=ink, anchor="ld")
    return _jpeg(img)


def gatefold(rec: dict, h: int = 800) -> bytes:
    w = h * 2
    img = Image.new("RGB", (w, h), _rgb(rec["hue"], 0.35, 0.25))
    d = ImageDraw.Draw(img)
    d.rectangle([w // 2, 0, w, h], fill=_rgb(rec["hue"], 0.35, 0.2))
    d.line([w // 2, 0, w // 2, h], fill=_rgb(rec["hue"], 0.3, 0.12), width=4)
    d.text((w // 4, h // 2), "Gatefold left", font=_font(h // 14),
           fill=(235, 232, 225), anchor="mm")
    d.text((3 * w // 4, h // 2), "Gatefold right", font=_font(h // 14),
           fill=(235, 232, 225), anchor="mm")
    return _jpeg(img)


def inner_sleeve(rec: dict, side: str, size: int = 1000) -> bytes:
    img = Image.new("RGB", (size, size), (238, 233, 222))
    d = ImageDraw.Draw(img)
    r = int(size * 0.12)
    c = size // 2
    d.ellipse([c - r, c - r, c + r, c + r], fill=(222, 216, 203))
    d.text((c, int(size * 0.1)), f"Inner sleeve ({side})", font=_font(int(size * 0.04)),
           fill=(110, 104, 96), anchor="mm")
    return _jpeg(img)


def disc_label(rec: dict, side: str, disc: int, size: int = 1000) -> bytes:
    img = Image.new("RGB", (size, size), (228, 226, 222))
    d = ImageDraw.Draw(img)
    c = size // 2
    r = int(size * 0.47)
    d.ellipse([c - r, c - r, c + r, c + r], fill=(22, 22, 24))
    for k in range(18):
        rr = r - 12 - k * 13
        d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=(38, 38, 42), width=2)
    lr = int(size * 0.17)
    d.ellipse([c - lr, c - lr, c + lr, c + lr], fill=_rgb(rec["hue"], rec.get("sat", 0.5), 0.55))
    d.text((c, c - int(lr * 0.55)), rec.get("label", ""), font=_font(int(size * 0.028)),
           fill=(20, 20, 20), anchor="mm")
    d.text((c, c + int(lr * 0.45)), f"Side {side}" if rec.get("disc_count", 1) == 1
           else f"Disc {disc}  Side {side}", font=_font(int(size * 0.026)),
           fill=(20, 20, 20), anchor="mm")
    h = int(size * 0.012)
    d.ellipse([c - h, c - h, c + h, c + h], fill=(228, 226, 222))
    return _jpeg(img)


def build_photos(rec: dict) -> dict[str, bytes]:
    wanted = rec.get("photos", [])
    files: dict[str, bytes] = {}
    if "front" in wanted:
        files["sleeve_front"] = sleeve_front(rec)
    if "back" in wanted:
        files["sleeve_back"] = sleeve_back(rec)
    if "gatefold" in wanted:
        files["sleeve_inner"] = gatefold(rec)
    if "inner" in wanted and not rec.get("outer_sleeve_only"):
        files["inner_sleeve_front"] = inner_sleeve(rec, "front")
        files["inner_sleeve_back"] = inner_sleeve(rec, "back")
    if "discs" in wanted:
        for disc in range(1, rec.get("disc_count", 1) + 1):
            files[f"disc_front_{disc}"] = disc_label(rec, "A" if disc == 1 else "C", disc)
            files[f"disc_back_{disc}"] = disc_label(rec, "B" if disc == 1 else "D", disc)
    return files


# ---------------------------------------------------------------------------
# API calls
# ---------------------------------------------------------------------------

_RECORD_FIELDS = (
    "title", "artist", "year", "duration", "label", "format", "speed", "genre", "notes",
    "owner", "disc_count", "outer_sleeve_only", "disc_condition", "sleeve_condition",
)


def _call(req: urllib.request.Request) -> tuple[int, bytes]:
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def _multipart(fields: dict[str, str], files: dict[str, bytes]) -> tuple[bytes, str]:
    boundary = uuid.uuid4().hex
    out = io.BytesIO()
    for name, value in fields.items():
        out.write(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n".encode())
        out.write(value.encode())
        out.write(b"\r\n")
    for name, data in files.items():
        out.write(
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"; "
            f"filename=\"{name}.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".encode()
        )
        out.write(data)
        out.write(b"\r\n")
    out.write(f"--{boundary}--\r\n".encode())
    return out.getvalue(), f"multipart/form-data; boundary={boundary}"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--url", default="http://localhost:8000", help="API base URL")
    ap.add_argument("--password", required=True, help="the server's PASSWORD")
    ap.add_argument("--force", action="store_true", help="add records even if the collection is not empty")
    args = ap.parse_args()

    base = args.url.rstrip("/")
    key = init_key(args.password)
    auth = {"Authorization": f"Bearer {derive_token(key)}"}

    status, body = _call(urllib.request.Request(f"{base}/api/v1/records?limit=1", headers=auth))
    if status == 401:
        print("The server rejected the password.", file=sys.stderr)
        return 1
    if status != 200:
        print(f"Could not list records: HTTP {status} {body[:200]!r}", file=sys.stderr)
        return 1
    existing = decrypt(key, json.loads(body))["total"]
    if existing and not args.force:
        print(f"The collection already has {existing} records. Use --force to add the demo set anyway.",
              file=sys.stderr)
        return 1

    for rec in DEMO_RECORDS:
        meta = {k: rec[k] for k in _RECORD_FIELDS if k in rec}
        payload, ctype = _multipart({"metadata": json.dumps(encrypt(key, meta))}, build_photos(rec))
        req = urllib.request.Request(f"{base}/api/v1/records/upload", data=payload, method="POST",
                                     headers={**auth, "Content-Type": ctype})
        status, body = _call(req)
        if status != 201:
            print(f"Failed to add {rec['artist']} - {rec['title']}: HTTP {status} {body[:200]!r}",
                  file=sys.stderr)
            return 1
        created = decrypt(key, json.loads(body))
        print(f"added  {created['artist']} - {created['title']}  ({len(created['photos'])} photos)")

    print(f"Done: {len(DEMO_RECORDS)} demo records.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
