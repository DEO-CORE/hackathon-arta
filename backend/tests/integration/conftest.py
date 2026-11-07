import io
import os
import uuid
from collections.abc import Iterator

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy import create_engine, text

from app.core.config import get_settings
from app.db.session import reset_engine


def _test_url() -> str:
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        pytest.fail("TEST_DATABASE_URL is required for integration tests (PostgreSQL)")
    if not url.split("?")[0].endswith("_test"):
        pytest.fail("TEST_DATABASE_URL must point at a database whose name ends with _test")
    return url


@pytest.fixture(scope="session", autouse=True)
def _migrated_db() -> Iterator[None]:
    _test_url()  # validates the target database name
    get_settings.cache_clear()
    reset_engine()
    cfg = Config("alembic.ini")
    command.downgrade(cfg, "base")
    command.upgrade(cfg, "head")
    yield
    reset_engine()


@pytest.fixture(autouse=True)
def _clean_tables() -> Iterator[None]:
    engine = create_engine(_test_url())
    with engine.begin() as conn:
        conn.execute(
            text(
                "TRUNCATE material_images, materials, users, organizations RESTART IDENTITY CASCADE"
            )
        )
    engine.dispose()
    yield


@pytest.fixture
def make_app():
    from app.main import create_app

    def factory():
        get_settings.cache_clear()
        return create_app()

    return factory


@pytest.fixture
def client(make_app) -> Iterator[TestClient]:
    with TestClient(make_app(), raise_server_exceptions=False) as c:
        yield c


def register(client: TestClient, role: str, email: str | None = None, **org) -> dict:
    email = email or f"{role}-{uuid.uuid4().hex[:8]}@example.test"
    body = {
        "email": email,
        "password": "correct-horse-battery",
        "role": role,
        "organization": {
            "name": org.get("name", "Демо организация"),
            "city": org.get("city", "Бишкек"),
            "activity_type": org.get("activity_type", "garment_factory"),
        },
    }
    r = client.post("/auth/register", json=body)
    assert r.status_code == 201, r.text
    return {"email": email, "password": body["password"], **r.json()}


def login_headers(client: TestClient, email: str, password: str = "correct-horse-battery") -> dict:  # noqa: S107
    r = client.post("/auth/login", json={"email": email, "password": password})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def seller(client):
    acc = register(client, "enterprise")
    return {**acc, "headers": login_headers(client, acc["email"])}


@pytest.fixture
def seller2(client):
    acc = register(client, "enterprise")
    return {**acc, "headers": login_headers(client, acc["email"])}


@pytest.fixture
def buyer(client):
    acc = register(client, "buyer", activity_type="workshop")
    return {**acc, "headers": login_headers(client, acc["email"])}


def png_bytes(size=(8, 8), fmt="PNG") -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", size, (200, 30, 30)).save(buf, format=fmt)
    return buf.getvalue()


def new_material(client, headers, **over) -> dict:
    body = {
        "name": "Хлопковые обрезки",
        "material_type": "cotton",
        "condition": "good",
        "city": "Бишкек",
        "total_kg": "120.500",
        "price_per_kg": "45.00",
    }
    body.update(over)
    r = client.post("/materials", json=body, headers=headers)
    assert r.status_code == 201, r.text
    return r.json()


def upload(client, headers, material_id, data: bytes | None = None, name="p.png", **form):
    return client.post(
        f"/materials/{material_id}/images",
        files={"file": (name, data if data is not None else png_bytes(), "image/png")},
        data=form,
        headers=headers,
    )


def ready_material(client, headers) -> dict:
    """Draft with photo and current confirmation, not yet published."""
    m = new_material(client, headers)
    r = upload(client, headers, m["id"])
    assert r.status_code == 201, r.text
    version = r.json()["material_version"]
    r = client.post(f"/materials/{m['id']}/confirm", json={"version": version}, headers=headers)
    assert r.status_code == 200, r.text
    return r.json()


def published_material(client, headers) -> dict:
    m = ready_material(client, headers)
    r = client.post(
        f"/materials/{m['id']}/publish", json={"version": m["version"]}, headers=headers
    )
    assert r.status_code == 200, r.text
    return r.json()


__all__ = ["png_bytes"]
