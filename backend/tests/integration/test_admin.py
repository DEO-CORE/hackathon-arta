import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import get_engine
from app.models import User
from app.models.enums import Role
from tests.integration.conftest import login_headers, register


@pytest.fixture
def admin(client):
    account = register(client, "enterprise")
    with Session(get_engine()) as db:
        user = db.scalar(select(User).where(User.email == account["email"]))
        user.role = Role.admin
        db.commit()
    return {
        "email": account["email"],
        "headers": login_headers(client, account["email"]),
        "id": account["user"]["id"],
    }


def test_admin_ui_and_role_boundary(client, seller, buyer, admin):
    page = client.get("/admin")
    assert page.status_code == 200
    assert "frame-ancestors" in page.headers["content-security-policy"]
    assert client.get("/admin/api/summary").status_code == 401
    for user in (seller, buyer):
        assert client.get("/admin/api/summary", headers=user["headers"]).status_code == 403
        assert client.get("/admin/api/records/users", headers=user["headers"]).status_code == 403
        assert (
            client.patch(
                "/admin/api/users/" + buyer["user"]["id"] + "/access",
                json={"active": False},
                headers=user["headers"],
            ).status_code
            == 403
        )
    assert client.get("/admin/api/me", headers=admin["headers"]).json()["role"] == "admin"
    summary = client.get("/admin/api/summary", headers=admin["headers"])
    assert summary.status_code == 200
    assert summary.json()["counts"]["users"] == 3
    for resource in (
        "users",
        "organizations",
        "materials",
        "requirements",
        "reservations",
        "transactions",
        "analyses",
        "plans",
    ):
        response = client.get("/admin/api/records/" + resource, headers=admin["headers"])
        assert response.status_code == 200, response.text
        assert "password_hash" not in response.text
        assert "storage_key" not in response.text
    assert (
        client.get("/admin/api/records/users?page=0", headers=admin["headers"]).status_code == 422
    )
    found = client.get(
        "/admin/api/records/users", params={"q": buyer["email"]}, headers=admin["headers"]
    ).json()
    assert found["total"] == 1


def test_admin_disables_and_restores_access(client, buyer, admin):
    url = "/admin/api/users/" + buyer["user"]["id"] + "/access"
    assert client.patch(url, json={"active": False}, headers=admin["headers"]).status_code == 200
    assert client.get("/organizations/me", headers=buyer["headers"]).status_code == 401
    assert (
        client.post(
            "/auth/login", json={"email": buyer["email"], "password": buyer["password"]}
        ).status_code
        == 403
    )
    assert client.patch(url, json={"active": True}, headers=admin["headers"]).status_code == 200
    assert client.get("/organizations/me", headers=buyer["headers"]).status_code == 200
    assert client.patch(url, json={"active": "false"}, headers=admin["headers"]).status_code == 422
    assert (
        client.patch(
            "/admin/api/users/" + admin["id"] + "/access",
            json={"active": False},
            headers=admin["headers"],
        ).status_code
        == 409
    )
