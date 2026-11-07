"""R2 (supplier workflow) and R3 (buyer marketplace) on PostgreSQL."""

import os
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text

from tests.integration.conftest import new_material, upload
from tests.integration.test_commerce import action, other_buyer, requirement, reserve


def publish(client, headers, **over):
    m = new_material(client, headers, **over)
    r = upload(client, headers, m["id"])
    assert r.status_code == 201, r.text
    r = client.post(
        f"/materials/{m['id']}/confirm",
        json={"version": r.json()["material_version"]},
        headers=headers,
    )
    assert r.status_code == 200, r.text
    r = client.post(
        f"/materials/{m['id']}/publish", json={"version": r.json()["version"]}, headers=headers
    )
    assert r.status_code == 200, r.text
    return r.json()


def balance(client, who, material):
    return client.get("/materials/" + material["id"], headers=who["headers"]).json()["balance"]


def audit_actions(target_id):
    engine = create_engine(os.environ["TEST_DATABASE_URL"])
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT action, actor_user_id::text, organization_id::text FROM audit_log "
                "WHERE target_id = :t ORDER BY created_at, id"
            ),
            {"t": target_id},
        ).all()
    engine.dispose()
    return rows


def test_full_chain_catalog_to_transactions(client, seller, seller2, buyer):
    m = publish(client, seller["headers"], total_kg="100.000", price_per_kg="40.00")
    found = client.get("/materials?q=хлопк", headers=buyer["headers"]).json()
    assert [i["id"] for i in found["items"]] == [m["id"]]
    assert "balance" not in found["items"][0] and "held_kg" not in found["items"][0]

    r = reserve(client, buyer, m, quantity="30.000")
    assert r.status_code == 201, r.text
    r = r.json()
    assert r["status"] == "pending"
    assert client.get("/transactions", headers=buyer["headers"]).json()["total"] == 0

    assert action(client, seller, r, "confirm").json()["status"] == "confirmed"
    assert balance(client, seller, m)["held_kg"] == "30.000"
    done = action(client, seller, r, "transfer", transferred_kg="25.000").json()
    assert done["status"] == "transferred"
    after = balance(client, seller, m)
    assert (after["held_kg"], after["transferred_kg"], after["available_kg"]) == (
        "0.000",
        "25.000",
        "75.000",
    )
    assert action(client, buyer, r, "complete").json()["status"] == "completed"

    for who in (seller, buyer):
        page = client.get("/transactions", headers=who["headers"]).json()
        assert page["total"] == 1
        t = page["items"][0]
        assert t["reservation_id"] == r["id"] and t["material_id"] == m["id"]
        assert t["transferred_kg"] == "25.000"
        assert t["sale_amount_kgs"] == "1000.00"
        assert t["status"] == "completed"
        assert t["transfer_confirmed_at"] and t["receipt_confirmed_at"]
        assert not {"seller_organization_id", "counterparty_contacts", "balance"} & t.keys()
        detail = client.get("/transactions/" + t["id"], headers=who["headers"])
        assert detail.status_code == 200 and detail.json() == t
    assert client.get("/transactions", headers=seller2["headers"]).json()["total"] == 0
    assert client.get("/transactions/" + t["id"], headers=seller2["headers"]).status_code == 404
    assert client.get("/transactions/not-a-uuid", headers=buyer["headers"]).status_code == 404
    assert client.get("/transactions/" + str(uuid4()), headers=buyer["headers"]).status_code == 404

    # Every state change is audited with actor and organization.
    rows = audit_actions(r["id"])
    assert [a for a, _, _ in rows] == [
        "reservation.created",
        "reservation.confirmed",
        "reservation.transferred",
        "reservation.completed",
    ]
    assert rows[0][1:] == (buyer["user"]["id"], buyer["user"]["organization_id"])
    assert rows[1][1:] == (seller["user"]["id"], seller["user"]["organization_id"])


def test_permissions_and_invalid_transitions(client, seller, seller2, buyer):
    m = publish(client, seller["headers"])
    r = reserve(client, buyer, m, quantity="10.000").json()
    assert action(client, buyer, r, "confirm").status_code == 403
    assert action(client, buyer, r, "transfer").status_code == 403
    assert action(client, seller2, r, "confirm").status_code == 404
    assert client.get("/reservations", headers=seller2["headers"]).json()["total"] == 0

    assert action(client, seller, r, "transfer").status_code == 409  # pending
    assert action(client, buyer, r, "complete").status_code == 409  # pending
    assert action(client, seller, r, "confirm").status_code == 200
    assert action(client, buyer, r, "complete").status_code == 409  # confirmed
    assert action(client, buyer, r, "cancel").status_code == 409  # held: seller only
    assert action(client, seller, r, "cancel").status_code == 422  # reason required
    assert action(client, seller, r, "transfer").status_code == 200
    assert action(client, seller, r, "cancel", reason="x").status_code == 409
    assert action(client, buyer, r, "complete").status_code == 200
    # Completed is final: nothing changes it (corrections are deferred).
    for who, name in ((seller, "confirm"), (seller, "transfer"), (buyer, "complete")):
        expected = 200 if name == "complete" else 409
        assert action(client, who, r, name).status_code == expected
    assert action(client, seller, r, "cancel", reason="x").status_code == 409
    assert action(client, buyer, r, "cancel").status_code == 409
    assert client.get("/reservations", headers=buyer["headers"]).json()["items"][0]["status"] == (
        "completed"
    )


def test_buyer_reads_own_status_and_cancels_only_pending(client, seller, seller2, buyer):
    m = publish(client, seller["headers"])
    r = reserve(client, buyer, m, quantity="10.000").json()
    got = client.get("/reservations?status=pending", headers=buyer["headers"]).json()
    assert [i["id"] for i in got["items"]] == [r["id"]]
    assert client.get("/reservations", headers=seller2["headers"]).json()["total"] == 0
    assert action(client, buyer, r, "cancel", reason="Передумал").json()["status"] == "cancelled"
    assert [a for a, _, _ in audit_actions(r["id"])] == [
        "reservation.created",
        "reservation.cancelled",
    ]


def test_idempotent_replay_creates_one_transaction(client, seller, buyer):
    m = publish(client, seller["headers"])
    key = str(uuid4())
    first = reserve(client, buyer, m, quantity="10.000", key=key)
    second = reserve(client, buyer, m, quantity="10.000", key=key)
    assert first.status_code == second.status_code == 201
    assert first.json() == second.json()
    r = first.json()
    assert client.get("/reservations", headers=buyer["headers"]).json()["total"] == 1

    assert action(client, seller, r, "confirm").status_code == 200
    url = "/reservations/" + r["id"]
    headers = seller["headers"] | {"Idempotency-Key": str(uuid4())}
    a = client.patch(url, json={"action": "transfer"}, headers=headers)
    b = client.patch(url, json={"action": "transfer"}, headers=headers)
    c = client.patch(url, json={"action": "transfer"}, headers=seller["headers"])  # no key
    assert a.status_code == b.status_code == c.status_code == 200
    assert a.json() == b.json() and b.headers["Idempotent-Replay"] == "true"
    assert c.json()["transaction"]["id"] == a.json()["transaction"]["id"]
    page = client.get("/transactions", headers=seller["headers"]).json()
    assert page["total"] == 1
    assert balance(client, seller, m)["transferred_kg"] == "10.000"
    created = [a for a, _, _ in audit_actions(r["id"])]
    assert created.count("reservation.transferred") == 1
    assert created.count("reservation.created") == 1


def test_concurrent_confirms_above_available_one_wins(client, seller, buyer):
    m = publish(client, seller["headers"], total_kg="100.000")
    a = reserve(client, buyer, m, quantity="70.000").json()
    b = reserve(client, other_buyer(client), m, quantity="70.000").json()
    barrier = Barrier(2)

    def confirm(r):
        with TestClient(client.app, raise_server_exceptions=False) as other:
            barrier.wait(timeout=10)
            return action(other, seller, r, "confirm").status_code

    with ThreadPoolExecutor(2) as pool:
        assert sorted(pool.map(confirm, [a, b])) == [200, 409]
    bal = balance(client, seller, m)
    assert (bal["available_kg"], bal["held_kg"]) == ("30.000", "70.000")


def test_cancel_confirmed_releases_stock_and_demand(client, seller, buyer):
    m = publish(client, seller["headers"], total_kg="100.000")
    req = requirement(client, buyer, max_kg="60.000")
    r = reserve(client, buyer, m, req, quantity="40.000").json()
    assert action(client, seller, r, "confirm").status_code == 200
    bal = balance(client, seller, m)
    assert (bal["available_kg"], bal["held_kg"]) == ("60.000", "40.000")
    demand = client.get("/buyer-requirements", headers=buyer["headers"]).json()["items"][0]
    assert demand["remaining_demand_kg"] == "20.000"

    cancelled = action(client, seller, r, "cancel", reason="Нет возможности")
    assert cancelled.json()["status"] == "cancelled"
    bal = balance(client, seller, m)
    assert (bal["available_kg"], bal["held_kg"]) == ("100.000", "0.000")
    demand = client.get("/buyer-requirements", headers=buyer["headers"]).json()["items"][0]
    assert demand["remaining_demand_kg"] == "60.000"
    assert "reservation.cancelled" in [a for a, _, _ in audit_actions(r["id"])]
    assert client.get("/transactions", headers=buyer["headers"]).json()["total"] == 0


def test_catalog_search_and_filters(client, seller, seller2, buyer):
    h = seller["headers"]
    cotton = publish(client, h, name="Белый ситец", total_kg="50.000", price_per_kg="30.00")
    wool = publish(
        client, h, name="Серая пряжа", material_type="wool", city="Ош", total_kg="200.000"
    )
    denim = publish(
        client, seller2["headers"], name="Синий джинс", material_type="denim", total_kg="10.000"
    )
    draft = new_material(client, h, name="Черновик хлопок")  # never visible to buyers

    def ids(query):
        r = client.get("/materials" + query, headers=buyer["headers"])
        assert r.status_code == 200, r.text
        return [i["id"] for i in r.json()["items"]]

    assert set(ids("")) == {cotton["id"], wool["id"], denim["id"]}
    assert draft["id"] not in ids("")
    assert ids("?q=пряжа") == [wool["id"]]
    assert ids("?q=denim") == [denim["id"]]  # search by type
    assert ids("?material_type=wool") == [wool["id"]]
    assert set(ids("?material_type=wool&material_type=denim")) == {wool["id"], denim["id"]}
    assert ids("?city=ош") == [wool["id"]]
    assert len(ids("?condition=good")) == 3
    assert ids("?condition=worn") == []
    assert set(ids("?min_available_kg=40")) == {cotton["id"], wool["id"]}
    assert set(ids("?max_available_kg=60")) == {cotton["id"], denim["id"]}
    assert ids("?min_available_kg=40&max_available_kg=60") == [cotton["id"]]
    assert ids("?sort=available_kg_desc")[0] == wool["id"]
    assert ids("?sort=created_at_desc") == [denim["id"], wool["id"], cotton["id"]]
    assert client.get("/materials?q=" + "а" * 101, headers=buyer["headers"]).status_code == 422
    # A SQL-LIKE wildcard in the query is literal text, not a pattern.
    assert ids("?q=%25") == []
    # Suppliers still see only their own materials, including drafts.
    own = client.get("/materials", headers=h).json()
    assert {i["id"] for i in own["items"]} == {cotton["id"], wool["id"], draft["id"]}


def test_one_active_reservation_per_buyer_and_material(client, seller, buyer):
    m = publish(client, seller["headers"])
    first = reserve(client, buyer, m, quantity="10.000").json()
    dup = reserve(client, buyer, m, quantity="5.000")
    assert dup.status_code == 409
    assert dup.json()["error"]["code"] == "ACTIVE_RESERVATION_EXISTS"
    assert action(client, seller, first, "confirm").status_code == 200
    assert reserve(client, buyer, m, quantity="5.000").status_code == 409
    assert action(client, seller, first, "cancel", reason="Нет").status_code == 200
    assert reserve(client, buyer, m, quantity="5.000").status_code == 201  # slot freed
    # Seller list exposes the buyer organization name; buyer list does not.
    s_item = client.get("/reservations", headers=seller["headers"]).json()["items"][0]
    b_item = client.get("/reservations", headers=buyer["headers"]).json()["items"][0]
    assert s_item["buyer_organization_name"] and b_item["buyer_organization_name"] is None


def test_catalog_aliases_and_missing_details(client, seller, buyer):
    a = publish(client, seller["headers"], total_kg="10.000")
    b = publish(client, seller["headers"], total_kg="90.000")
    q = "/materials?min_kg=20&sort=mass_asc"
    assert [i["id"] for i in client.get(q, headers=buyer["headers"]).json()["items"]] == [b["id"]]
    q = "/materials?sort=mass_desc"
    assert [i["id"] for i in client.get(q, headers=buyer["headers"]).json()["items"]] == [
        b["id"],
        a["id"],
    ]
    draft = new_material(client, seller["headers"])
    r = client.post(
        f"/materials/{draft['id']}/publish",
        json={"version": draft["version"]},
        headers=seller["headers"],
    )
    assert r.status_code == 422
    missing = r.json()["error"]["details"]["missing"]
    assert missing and all(isinstance(f, str) for f in missing)
    noprice = publish(client, seller["headers"], price_per_kg=None)
    bad = reserve(client, buyer, noprice, quantity="1.000")
    assert bad.status_code == 422
    assert bad.json()["error"]["details"]["missing"] == ["agreed_price_per_kg"]
