import io
import os
from pathlib import Path

from PIL import Image
from sqlalchemy import create_engine, text

from tests.integration.conftest import (
    new_material,
    png_bytes,
    published_material,
    ready_material,
    upload,
)


def test_upload_png_stores_key_not_url_and_bumps_version(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    r = upload(client, h, m["id"])
    assert r.status_code == 201
    body = r.json()
    img = body["image"]
    assert body["material_version"] == 2
    assert img["mime_type"] == "image/png" and (img["width_px"], img["height_px"]) == (8, 8)
    assert img["sort_order"] == 0 and "storage_key" not in img and "url" not in str(img).lower()

    engine = create_engine(os.environ["DATABASE_URL"])
    with engine.connect() as c:
        key = c.execute(text("select storage_key from material_images")).scalar_one()
    engine.dispose()
    assert key.startswith(f"materials/{m['id']}/") and "://" not in key
    assert (Path(os.environ["STORAGE_LOCAL_DIR"]) / key).is_file()

    card = client.get(f"/materials/{m['id']}", headers=h).json()
    assert [i["id"] for i in card["images"]] == [img["id"]]
    assert "storage_key" not in str(card)


def test_upload_accepts_jpeg_and_webp(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    for fmt, mime in (("JPEG", "image/jpeg"), ("WEBP", "image/webp")):
        r = upload(client, h, m["id"], data=png_bytes(fmt=fmt), name="x.bin")
        assert r.status_code == 201, r.text
        assert r.json()["image"]["mime_type"] == mime


def test_upload_rejects_wrong_signature_even_with_image_content_type(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    for payload in (b"GIF89a" + b"0" * 50, b"<svg></svg>", b"%PDF-1.4 hello", b""):
        r = upload(client, h, m["id"], data=payload)
        assert r.status_code == 422, payload
        assert r.json()["error"]["code"] == "UNSUPPORTED_IMAGE"
        assert r.json()["error"]["details"]["reason"] == "signature"


def test_upload_rejects_truncated_image_as_decode(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    r = upload(client, h, m["id"], data=png_bytes((64, 64))[:60])
    assert r.status_code == 422 and r.json()["error"]["details"]["reason"] == "decode"


def test_upload_rejects_too_many_pixels(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    buf = io.BytesIO()
    Image.new("1", (5000, 4001)).save(buf, format="PNG")  # 20_005_000 px, tiny file
    r = upload(client, h, m["id"], data=buf.getvalue())
    assert r.status_code == 422
    assert r.json()["error"]["details"] == {"reason": "pixels", "max_pixels": 20_000_000}


def test_upload_rejects_over_10mb(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    r = upload(client, h, m["id"], data=b"\x89PNG\r\n\x1a\n" + b"0" * (10 * 1024 * 1024 + 1))
    assert r.status_code == 422
    assert r.json()["error"]["details"] == {"reason": "bytes", "max_bytes": 10 * 1024 * 1024}


def test_upload_strips_exif(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    exif = Image.Exif()
    exif[0x010F] = "SecretCameraMaker"
    buf = io.BytesIO()
    Image.new("RGB", (8, 8)).save(buf, format="JPEG", exif=exif)
    assert b"SecretCameraMaker" in buf.getvalue()
    r = upload(client, h, m["id"], data=buf.getvalue())
    assert r.status_code == 201
    engine = create_engine(os.environ["DATABASE_URL"])
    with engine.connect() as c:
        key = c.execute(text("select storage_key from material_images")).scalar_one()
    engine.dispose()
    assert b"SecretCameraMaker" not in (Path(os.environ["STORAGE_LOCAL_DIR"]) / key).read_bytes()


def test_image_limit_5_then_409(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    for _ in range(5):
        assert upload(client, h, m["id"]).status_code == 201
    r = upload(client, h, m["id"])
    assert r.status_code == 409
    assert r.json()["error"]["code"] == "IMAGE_LIMIT_REACHED"
    assert r.json()["error"]["details"] == {"max_images": 5}


def test_limit_checked_before_format(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    for _ in range(5):
        upload(client, h, m["id"])
    r = upload(client, h, m["id"], data=b"not an image")
    assert r.status_code == 409


def test_missing_file_and_bad_sort_order(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    r = client.post(f"/materials/{m['id']}/images", headers=h, data={"sort_order": "1"})
    assert r.status_code == 422
    assert r.json()["error"]["details"]["errors"][0] == {
        "field": "file",
        "code": "required",
        "message": "Поле обязательно.",
    }
    r = upload(client, h, m["id"], sort_order="-1")
    assert (
        r.status_code == 422 and r.json()["error"]["details"]["errors"][0]["field"] == "sort_order"
    )


def test_sort_order_shifts_existing(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    a = upload(client, h, m["id"]).json()["image"]
    b = upload(client, h, m["id"]).json()["image"]
    assert (a["sort_order"], b["sort_order"]) == (0, 1)
    c = upload(client, h, m["id"], sort_order="0").json()["image"]
    card = client.get(f"/materials/{m['id']}", headers=h).json()
    assert [(i["id"], i["sort_order"]) for i in card["images"]] == [
        (c["id"], 0),
        (a["id"], 1),
        (b["id"], 2),
    ]


def test_upload_invalidates_confirmation_and_republishes_to_draft(client, seller):
    h = seller["headers"]
    m = ready_material(client, h)
    assert m["is_confirmation_current"] is True
    r = upload(client, h, m["id"])
    card = client.get(f"/materials/{m['id']}", headers=h).json()
    assert card["version"] == r.json()["material_version"] == m["version"] + 1
    assert card["is_confirmation_current"] is False

    pub = published_material(client, h)
    upload(client, h, pub["id"])
    assert client.get(f"/materials/{pub['id']}", headers=h).json()["status"] == "draft"


def test_confirm_after_upload_with_old_version_conflicts(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    upload(client, h, m["id"])
    r = client.post(f"/materials/{m['id']}/confirm", json={"version": 1}, headers=h)
    assert r.status_code == 409 and r.json()["error"]["details"] == {"current_version": 2}
