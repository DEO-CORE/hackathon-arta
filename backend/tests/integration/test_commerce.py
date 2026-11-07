from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from uuid import uuid4

from fastapi.testclient import TestClient

from tests.integration.conftest import published_material


def requirement(client, buyer, **over):
    body = dict(
        material_types=["cotton"],
        conditions=["good"],
        min_kg="1.000",
        max_kg="100.000",
        budget_per_kg="50.00",
        city="Бишкек",
    )
    response = client.post("/buyer-requirements", json=body | over, headers=buyer["headers"])
    assert response.status_code == 201, response.text
    return response.json()


def reserve(client, buyer, material, req=None, quantity="50.000", key=None):
    return client.post(
        "/reservations",
        json=dict(
            material_id=material["id"],
            requirement_id=req["id"] if req else None,
            quantity_kg=quantity,
        ),
        headers=buyer["headers"] | {"Idempotency-Key": key or str(uuid4())},
    )


def action(client, who, reservation, name, **over):
    return client.patch(
        "/reservations/" + reservation["id"], json=dict(action=name) | over, headers=who["headers"]
    )


def test_full_lifecycle_and_analytics(client, seller, buyer, seller2):
    m = published_material(client, seller["headers"])
    req = requirement(client, buyer)
    r = reserve(client, buyer, m, req)
    assert r.status_code == 201, r.text
    r = r.json()
    assert r["counterparty_contacts"] is None
    assert action(client, seller2, r, "confirm").status_code == 404
    assert action(client, buyer, r, "confirm").status_code == 403
    assert action(client, seller, r, "confirm").status_code == 200
    assert action(client, seller, r, "confirm").status_code == 200
    transferred = action(client, seller, r, "transfer", transferred_kg="40.000")
    assert transferred.status_code == 200, transferred.text
    tx = transferred.json()["transaction"]
    assert action(client, seller, r, "transfer").json()["transaction"]["id"] == tx["id"]
    summary = client.get("/analytics/summary", headers=seller["headers"]).json()
    assert summary["revenue_kgs"] == "0.00"
    assert summary["confirmed_reuse_kg"] == "0.000"
    assert action(client, buyer, r, "complete").status_code == 200
    key = str(uuid4())
    url = f"/transactions/{tx['id']}/reuse-confirmation"
    body = dict(reused_kg="25.000", basis="Пошив сумок")
    response = client.post(url, json=body, headers=buyer["headers"] | {"Idempotency-Key": key})
    assert response.status_code == 201, response.text
    replay = client.post(url, json=body, headers=buyer["headers"] | {"Idempotency-Key": key})
    assert replay.json() == response.json()
    assert replay.headers["Idempotent-Replay"] == "true"
    assert (
        client.post(
            url, json=body, headers=buyer["headers"] | {"Idempotency-Key": str(uuid4())}
        ).status_code
        == 422
    )
    summary = client.get("/analytics/summary", headers=seller["headers"]).json()
    assert summary["revenue_kgs"] == "1800.00"
    assert summary["confirmed_reuse_kg"] == "25.000"
    assert summary["distributed_kg"] == "40.000"
    balance = client.get("/materials/" + m["id"], headers=seller["headers"]).json()["balance"]
    assert balance == dict(
        total_kg="120.500",
        available_kg="80.500",
        held_kg="0.000",
        transferred_kg="40.000",
        internally_used_kg="0.000",
    )
    req = client.get("/buyer-requirements", headers=buyer["headers"]).json()["items"][0]
    assert req["remaining_demand_kg"] == "60.000"


def test_idempotency_and_cancel(client, seller, buyer):
    m = published_material(client, seller["headers"])
    req = requirement(client, buyer)
    key = str(uuid4())
    first = reserve(client, buyer, m, req, key=key)
    second = reserve(client, buyer, m, req, key=key)
    assert first.json() == second.json()
    assert second.headers["Idempotent-Replay"] == "true"
    assert reserve(client, buyer, m, req, quantity="1.000", key=key).status_code == 409
    r = first.json()
    assert action(client, seller, r, "confirm").status_code == 200
    response = client.patch(
        "/buyer-requirements/" + req["id"], json={"max_kg": "10.000"}, headers=buyer["headers"]
    )
    assert response.status_code == 409
    assert action(client, buyer, r, "cancel").status_code == 200
    assert action(client, buyer, r, "cancel").status_code == 200
    assert (
        client.get("/materials/" + m["id"], headers=seller["headers"]).json()["balance"][
            "available_kg"
        ]
        == "120.500"
    )
    assert (
        "budget_per_kg"
        not in client.get("/buyer-requirements", headers=seller["headers"]).json()["items"][0]
    )


def test_concurrent_reservations_cannot_oversell(client, seller, buyer):
    m = published_material(client, seller["headers"])
    a = reserve(client, buyer, m, quantity="80.000").json()
    b = reserve(client, buyer, m, quantity="80.000").json()

    barrier = Barrier(2)

    def confirm(r):
        with TestClient(client.app, raise_server_exceptions=False) as other:
            barrier.wait(timeout=10)
            return action(other, seller, r, "confirm").status_code

    with ThreadPoolExecutor(2) as pool:
        assert sorted(pool.map(confirm, [a, b])) == [200, 409]
    balance = client.get("/materials/" + m["id"], headers=seller["headers"]).json()["balance"]
    assert balance["available_kg"] == "40.500"
    assert balance["held_kg"] == "80.000"


def test_concurrent_same_key_creates_one_reservation(client, seller, buyer):
    m = published_material(client, seller["headers"])
    key = str(uuid4())

    barrier = Barrier(2)

    def create(_):
        with TestClient(client.app, raise_server_exceptions=False) as other:
            barrier.wait(timeout=10)
            return reserve(other, buyer, m, key=key)

    with ThreadPoolExecutor(2) as pool:
        responses = list(pool.map(create, range(2)))
    assert [r.status_code for r in responses] == [201, 201]
    assert responses[0].json() == responses[1].json()
    assert client.get("/reservations", headers=buyer["headers"]).json()["total"] == 1


def test_internal_use_archive_and_validation(client, seller, buyer):
    m = published_material(client, seller["headers"])
    pending = reserve(client, buyer, m).json()
    url = "/materials/" + m["id"] + "/internal-use"
    headers = seller["headers"] | {"Idempotency-Key": str(uuid4())}
    body = dict(quantity_kg="20.000", basis="Пошив образцов")
    first = client.post(url, json=body, headers=headers)
    assert first.status_code == 201, first.text
    assert client.post(url, json=body, headers=headers).json() == first.json()
    assert client.post(url, json=body | {"quantity_kg": 20}, headers=headers).status_code == 422
    archived = client.post(
        "/materials/" + m["id"] + "/archive",
        json={"version": m["version"]},
        headers=seller["headers"],
    )
    assert archived.status_code == 200
    rows = client.get("/reservations", headers=buyer["headers"]).json()["items"]
    assert rows[0]["id"] == pending["id"] and rows[0]["cancel_reason"] == "MATERIAL_ARCHIVED"


def test_shared_demand_is_locked_across_materials(client, seller, buyer):
    req = requirement(client, buyer, max_kg="100.000")
    materials = [published_material(client, seller["headers"]) for _ in range(2)]
    reservations = [reserve(client, buyer, m, req, quantity="60.000").json() for m in materials]
    barrier = Barrier(2)

    def confirm(r):
        with TestClient(client.app, raise_server_exceptions=False) as other:
            barrier.wait(timeout=10)
            return action(other, seller, r, "confirm")

    with ThreadPoolExecutor(2) as pool:
        results = list(pool.map(confirm, reservations))
    assert sorted(r.status_code for r in results) == [200, 409]
    failure = next(r for r in results if r.status_code == 409)
    assert failure.json()["error"]["code"] == "DEMAND_EXCEEDED"
    assert (
        client.get("/buyer-requirements", headers=buyer["headers"]).json()["items"][0][
            "remaining_demand_kg"
        ]
        == "40.000"
    )


def test_concurrent_reuse_cannot_exceed_transfer(client, seller, buyer):
    m = published_material(client, seller["headers"])
    r = reserve(client, buyer, m, quantity="40.000").json()
    assert action(client, seller, r, "confirm").status_code == 200
    tx = action(client, seller, r, "transfer").json()["transaction"]
    assert action(client, buyer, r, "complete").status_code == 200
    barrier = Barrier(2)

    def reuse(_):
        with TestClient(client.app, raise_server_exceptions=False) as other:
            barrier.wait(timeout=10)
            return other.post(
                "/transactions/" + tx["id"] + "/reuse-confirmation",
                json=dict(reused_kg="25.000", basis="Пошив изделий"),
                headers=buyer["headers"] | {"Idempotency-Key": str(uuid4())},
            )

    with ThreadPoolExecutor(2) as pool:
        results = list(pool.map(reuse, range(2)))
    assert sorted(r.status_code for r in results) == [201, 422]
    assert (
        client.get("/analytics/summary", headers=buyer["headers"]).json()["confirmed_reuse_kg"]
        == "25.000"
    )


def test_business_conflict_replayed_after_stock_changes(client, seller, buyer):
    m = published_material(client, seller["headers"])
    first = reserve(client, buyer, m, quantity="80.000").json()
    second = reserve(client, buyer, m, quantity="80.000").json()
    assert action(client, seller, first, "confirm").status_code == 200
    headers = seller["headers"] | {"Idempotency-Key": str(uuid4())}
    url = "/reservations/" + second["id"]
    failure = client.patch(url, json={"action": "confirm"}, headers=headers)
    assert failure.status_code == 409
    assert action(client, buyer, first, "cancel").status_code == 200
    replay = client.patch(url, json={"action": "confirm"}, headers=headers)
    assert replay.status_code == 409 and replay.json() == failure.json()
    assert replay.headers["Idempotent-Replay"] == "true"
    assert action(client, seller, second, "confirm").status_code == 200
