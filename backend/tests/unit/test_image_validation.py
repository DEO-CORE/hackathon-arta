import io
import uuid

import pytest
from PIL import Image

from app.core.errors import AppError
from app.services.images import sniff_format, validate_and_clean


def _img(fmt, size=(4, 4), mode="RGB") -> bytes:
    buf = io.BytesIO()
    Image.new(mode, size).save(buf, format=fmt)
    return buf.getvalue()


@pytest.mark.parametrize(
    ("fmt", "mime"), [("JPEG", "image/jpeg"), ("PNG", "image/png"), ("WEBP", "image/webp")]
)
def test_valid_formats(fmt, mime):
    mid = uuid.uuid4()
    out = validate_and_clean(_img(fmt), mid)
    assert out.mime_type == mime and (out.width, out.height) == (4, 4)
    assert out.key.startswith(f"materials/{mid}/") and ".." not in out.key


def test_signature_vs_content_mismatch_rejected():
    # PNG magic bytes followed by JPEG payload: decoder format disagrees with signature
    data = b"\x89PNG\r\n\x1a\n" + _img("JPEG")
    with pytest.raises(AppError) as e:
        validate_and_clean(data, uuid.uuid4())
    assert e.value.details["reason"] in ("signature", "decode")


def test_sniff_none_for_unknown():
    assert sniff_format(b"GIF89a") is None and sniff_format(b"") is None


def test_palette_png_roundtrip():
    out = validate_and_clean(_img("PNG", mode="P"), uuid.uuid4())
    assert out.mime_type == "image/png"


def test_random_keys_differ():
    mid = uuid.uuid4()
    data = _img("PNG")
    assert validate_and_clean(data, mid).key != validate_and_clean(data, mid).key
