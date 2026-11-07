"""Upload validation: signature, size, decoding, pixel limit (CLAUDE.md section 11)."""

import io
import uuid
from dataclasses import dataclass

from PIL import Image, UnidentifiedImageError

from app.core.errors import AppError

MAX_BYTES = 10 * 1024 * 1024
MAX_PIXELS = 20_000_000
MAX_IMAGES = 5

_FORMATS = {
    "JPEG": ("image/jpeg", "jpg"),
    "PNG": ("image/png", "png"),
    "WEBP": ("image/webp", "webp"),
}


@dataclass(frozen=True)
class ValidatedImage:
    data: bytes  # re-encoded without metadata
    mime_type: str
    width: int
    height: int
    key: str


def _unsupported(reason: str, **extra: int) -> AppError:
    return AppError(422, "UNSUPPORTED_IMAGE", details={"reason": reason, **extra})


def sniff_format(head: bytes) -> str | None:
    if head.startswith(b"\xff\xd8\xff"):
        return "JPEG"
    if head.startswith(b"\x89PNG\r\n\x1a\n"):
        return "PNG"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "WEBP"
    return None


def validate_and_clean(raw: bytes, material_id: uuid.UUID) -> ValidatedImage:
    if len(raw) > MAX_BYTES:
        raise _unsupported("bytes", max_bytes=MAX_BYTES)
    fmt = sniff_format(raw[:16])
    if fmt is None:
        raise _unsupported("signature")
    try:
        with Image.open(io.BytesIO(raw)) as probe:
            if probe.format != fmt:
                raise _unsupported("signature")
            width, height = probe.size
            if width * height > MAX_PIXELS:
                raise _unsupported("pixels", max_pixels=MAX_PIXELS)
            probe.load()  # full decode: catches truncated/corrupt files
            # Re-encode from pixel data only: drops EXIF/GPS and any appended payload (A18-18).
            clean = probe.copy()
            clean.info = {}
    except AppError:
        raise
    except (UnidentifiedImageError, OSError, SyntaxError, ValueError, Image.DecompressionBombError):
        raise _unsupported("decode") from None
    out = io.BytesIO()
    save_kwargs = {"quality": 90} if fmt in ("JPEG", "WEBP") else {}
    clean.save(out, format=fmt, **save_kwargs)
    mime, ext = _FORMATS[fmt]
    key = f"materials/{material_id}/{uuid.uuid4().hex}.{ext}"
    return ValidatedImage(out.getvalue(), mime, width, height, key)
