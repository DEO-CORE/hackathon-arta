import threading
import uuid

from sqlalchemy import create_engine, text

from tests.integration.conftest import (
    new_material,
    published_material,
    ready_material,
    upload,
)


def _sql(query: str, **params):
    engine = create_engine(__import__("os").environ["DATABASE_URL"])
    with engine.begin() as c:
        res = c.execute(text(query), params)
        rows = res.fetchall() if res.returns_rows else None
    engine.dispose()
    return rows


# ---------- create / read / roles ----------


def test_create_draft_defaults(client, seller):
    r = client.post("/materials", json={"name": "Обрезки"}, headers=seller["headers"])
    assert r.status_code == 201
    m = r.json()
    assert r.headers["location"] == f"/materials/{m['id']}"
    assert m["status"] == "draft" and m["version"] == 1
    assert m["balance"] == {
        "total_kg": "0.000",
        "available_kg": "0.000",
        "held_kg": "0.000",
        "transferred_kg": "0.000",
        "internally_used_kg": "0.000",
    }
    assert m["is_confirmation_current"] is False and m["images"] == []
    assert m["organization_id"] == seller["organization"]["id"]


def test_create_decimal_strings_and_balance(client, seller):
    m = new_material(client, seller["headers"])
    assert m["price_per_kg"] == "45.00"
    assert m["balance"]["total_kg"] == m["balance"]["available_kg"] == "120.500"


def test_decimal_validation(client, seller):
    h = seller["headers"]
    cases = {
        ("total_kg", 12.5): "invalid_type",
        ("total_kg", "12.5555"): "too_many_decimals",
        ("total_kg", "-1"): "out_of_range",
        ("total_kg", "abc"): "invalid_decimal",
        ("price_per_kg", "1.234"): "too_many_decimals",
        ("price_per_kg", 10): "invalid_type",
        ("total_kg", "1234567890"): "out_of_range",
        ("composition", ""): "too_short",
        ("material_type", "plastic"): "invalid_value",
    }
    for (field, value), code in cases.items():
        r = client.post("/materials", json={"name": "x", field: value}, headers=h)
        assert r.status_code == 422, (field, value)
        errs = r.json()["error"]["details"]["errors"]
        assert errs[0]["field"] == field and errs[0]["code"] == code, (field, value, errs)
        # the client's value is not echoed back in any error message
        assert all(str(value) not in e["message"] for e in errs if value != "")


def test_create_rejects_status_and_unknown_fields(client, seller):
    r = client.post(
        "/materials",
        json={"name": "x", "status": "available", "version": 9},
        headers=seller["headers"],
    )
    assert r.status_code == 422
    codes = {(e["field"], e["code"]) for e in r.json()["error"]["details"]["errors"]}
    assert codes == {("status", "extra_forbidden"), ("version", "extra_forbidden")}


def test_buyer_cannot_create_or_mutate(client, buyer, seller):
    """Hidden (draft) material: 404 first. Visible published material: 403. No resource ID: 403."""
    hb = buyer["headers"]
    assert client.post("/materials", json={"name": "x"}, headers=hb).status_code == 403
    draft = new_material(client, seller["headers"])
    pub = published_material(client, seller["headers"])
    calls = [
        ("patch", "", {"version": 1, "name": "y"}),
        ("post", "/confirm", {"version": 1}),
        ("post", "/publish", {"version": 1}),
        ("post", "/archive", {"version": 1}),
    ]
    for method, suffix, body in calls:
        r = getattr(client, method)(f"/materials/{draft['id']}{suffix}", json=body, headers=hb)
        assert r.status_code == 404, (method, suffix)
        r = getattr(client, method)(f"/materials/{pub['id']}{suffix}", json=body, headers=hb)
        assert r.status_code == 403 and r.json()["error"]["code"] == "FORBIDDEN", (method, suffix)
        r = getattr(client, method)(f"/materials/{uuid.uuid4()}{suffix}", json=body, headers=hb)
        assert r.status_code == 404, (method, suffix)
    assert upload(client, hb, draft["id"]).status_code == 404
    assert upload(client, hb, pub["id"]).status_code == 403


def test_unauthenticated_materials_401(client):
    assert client.get("/materials").status_code == 401
    assert client.post("/materials", json={"name": "x"}).status_code == 401


def test_enterprise_foreign_material_is_404_everywhere(client, seller, seller2):
    m = new_material(client, seller["headers"])
    h2 = seller2["headers"]
    mid = m["id"]
    assert client.get(f"/materials/{mid}", headers=h2).status_code == 404
    assert (
        client.patch(f"/materials/{mid}", json={"version": 1, "name": "z"}, headers=h2).status_code
        == 404
    )
    for action in ("confirm", "publish", "archive"):
        r = client.post(f"/materials/{mid}/{action}", json={"version": 1}, headers=h2)
        assert r.status_code == 404, action
    assert upload(client, h2, mid).status_code == 404
    assert client.get("/materials", headers=h2).json()["total"] == 0


def test_malformed_id_is_404(client, seller):
    assert client.get("/materials/not-a-uuid", headers=seller["headers"]).status_code == 404
    assert (
        client.patch(
            "/materials/not-a-uuid", json={"version": 1, "name": "x"}, headers=seller["headers"]
        ).status_code
        == 404
    )


# ---------- buyer visibility ----------


def test_buyer_sees_only_published_public_fields(client, seller, buyer):
    draft = new_material(client, seller["headers"], name="Черновик")
    pub = published_material(client, seller["headers"])
    hb = buyer["headers"]

    assert client.get(f"/materials/{draft['id']}", headers=hb).status_code == 404
    r = client.get(f"/materials/{pub['id']}", headers=hb)
    assert r.status_code == 200
    body = r.json()
    for hidden in ("balance", "total_kg", "held_kg", "transferred_kg", "confirmed_by", "contacts"):
        assert hidden not in body
    assert body["available_kg"] == "120.500"
    assert "organization_name" not in body  # buyers see city and type only before a request

    lst = client.get("/materials", headers=hb).json()
    assert [i["id"] for i in lst["items"]] == [pub["id"]] and lst["total"] == 1


def test_buyer_does_not_see_reserved_completed_archived(client, seller, buyer):
    pub = published_material(client, seller["headers"])
    for status in ("reserved", "completed"):
        held = "120.500" if status == "reserved" else "0.000"
        transferred = "120.500" if status == "completed" else "0.000"
        _sql(
            "update materials set status=:s, available_kg=0, held_kg=:h, transferred_kg=:t where id=:i",
            s=status,
            h=held,
            t=transferred,
            i=pub["id"],
        )
        assert client.get(f"/materials/{pub['id']}", headers=buyer["headers"]).status_code == 404
        assert client.get("/materials", headers=buyer["headers"]).json()["total"] == 0
    _sql(
        "update materials set status='available', available_kg=total_kg, held_kg=0, transferred_kg=0 where id=:i",
        i=pub["id"],
    )
    v = client.get(f"/materials/{pub['id']}", headers=seller["headers"]).json()["version"]
    assert (
        client.post(
            f"/materials/{pub['id']}/archive", json={"version": v}, headers=seller["headers"]
        ).status_code
        == 200
    )
    assert client.get(f"/materials/{pub['id']}", headers=buyer["headers"]).status_code == 404


# ---------- list ----------


def test_list_pagination_filters_and_archive_default(client, seller):
    h = seller["headers"]
    a = new_material(
        client, h, name="Хлопок_100%", city="Бишкек", material_type="cotton", price_per_kg="10.00"
    )
    b = new_material(
        client,
        h,
        name="Шерсть",
        city="ош",
        material_type="wool",
        condition="worn",
        price_per_kg="30.00",
    )
    new_material(client, h, name="Без цены", price_per_kg=None)
    client.post(f"/materials/{b['id']}/archive", json={"version": 1}, headers=h)

    lst = client.get("/materials", headers=h).json()
    assert lst["total"] == 2 and {i["id"] for i in lst["items"]} != {b["id"]}
    arch = client.get("/materials", params={"status": "archived"}, headers=h).json()
    assert [i["id"] for i in arch["items"]] == [b["id"]]

    assert client.get("/materials", params={"q": "100%"}, headers=h).json()["total"] == 1
    assert client.get("/materials", params={"q": "%"}, headers=h).json()["total"] == 1  # escaped
    assert client.get("/materials", params={"q": "_"}, headers=h).json()["total"] == 1
    assert (
        client.get("/materials", params={"max_price_per_kg": "15.00"}, headers=h).json()["total"]
        == 1
    )
    assert client.get("/materials", params={"city": "БИШКЕК"}, headers=h).json()["total"] == 2
    assert (
        client.get("/materials", params={"material_type": ["cotton", "wool"]}, headers=h).json()[
            "total"
        ]
        == 2
    )
    assert (
        client.get("/materials", params={"sort": "price_asc"}, headers=h).json()["items"][0]["id"]
        == a["id"]
    )

    p = client.get("/materials", params={"page": 1, "page_size": 1}, headers=h).json()
    assert len(p["items"]) == 1 and p["total"] == 2 and p["page_size"] == 1
    assert client.get("/materials", params={"page": 9}, headers=h).json()["items"] == []


def test_list_param_validation(client, seller):
    h = seller["headers"]
    r = client.get("/materials", params={"page_size": 101}, headers=h)
    assert r.status_code == 422
    assert r.json()["error"]["details"]["errors"][0] == {
        "field": "page_size",
        "code": "out_of_range",
        "message": "Значение вне допустимого диапазона.",
    }
    assert client.get("/materials", params={"page": 0}, headers=h).status_code == 422
    assert client.get("/materials", params={"status": "bogus"}, headers=h).status_code == 422
    r = client.get("/materials", params={"q": ""}, headers=h)
    assert r.status_code == 422 and r.json()["error"]["details"]["errors"][0]["code"] == "too_short"


# ---------- PATCH / versions ----------


def test_patch_bumps_version_and_missing_version_is_422(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    r = client.patch(f"/materials/{m['id']}", json={"name": "Новое"}, headers=h)
    assert r.status_code == 422
    assert r.json()["error"]["details"]["errors"][0]["field"] == "version"
    r = client.patch(f"/materials/{m['id']}", json={"version": 1}, headers=h)
    assert (
        r.status_code == 422 and r.json()["error"]["details"]["errors"][0]["code"] == "no_changes"
    )
    r = client.patch(f"/materials/{m['id']}", json={"version": 1, "name": "Новое"}, headers=h)
    assert r.status_code == 200 and r.json()["version"] == 2 and r.json()["name"] == "Новое"


def test_patch_stale_version_409_and_nothing_applied(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    assert (
        client.patch(
            f"/materials/{m['id']}", json={"version": 1, "name": "A"}, headers=h
        ).status_code
        == 200
    )
    r = client.patch(f"/materials/{m['id']}", json={"version": 1, "name": "B"}, headers=h)
    assert r.status_code == 409
    err = r.json()["error"]
    assert err["code"] == "VERSION_CONFLICT" and err["details"] == {"current_version": 2}
    assert client.get(f"/materials/{m['id']}", headers=h).json()["name"] == "A"


def test_patch_same_values_does_not_bump_version(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    r = client.patch(f"/materials/{m['id']}", json={"version": 1, "city": m["city"]}, headers=h)
    assert r.status_code == 200 and r.json()["version"] == 1


def test_patch_null_clears_optional_but_not_name(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    r = client.patch(f"/materials/{m['id']}", json={"version": 1, "price_per_kg": None}, headers=h)
    assert r.status_code == 200 and r.json()["price_per_kg"] is None
    r = client.patch(f"/materials/{m['id']}", json={"version": 2, "name": None}, headers=h)
    assert (
        r.status_code == 422
        and r.json()["error"]["details"]["errors"][0]["code"] == "null_not_allowed"
    )
    r = client.patch(f"/materials/{m['id']}", json={"version": 2, "status": "available"}, headers=h)
    assert r.status_code == 422
    assert r.json()["error"]["details"]["errors"][0]["code"] == "extra_forbidden"


def test_concurrent_patch_same_version_exactly_one_wins(make_app, seller):
    from fastapi.testclient import TestClient

    app = make_app()
    results: list[int] = []
    barrier = threading.Barrier(2)
    with TestClient(app, raise_server_exceptions=False) as c:
        m = new_material(c, seller["headers"])

        def worker(name: str) -> None:
            barrier.wait()
            r = c.patch(
                f"/materials/{m['id']}",
                json={"version": 1, "name": name},
                headers=seller["headers"],
            )
            results.append(r.status_code)

        threads = [threading.Thread(target=worker, args=(n,)) for n in ("A", "B")]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        assert sorted(results) == [200, 409]
        assert c.get(f"/materials/{m['id']}", headers=seller["headers"]).json()["version"] == 2


def test_total_kg_updates_available_and_zero_only_for_draft(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    r = client.patch(f"/materials/{m['id']}", json={"version": 1, "total_kg": "0.000"}, headers=h)
    assert r.status_code == 200 and r.json()["balance"]["available_kg"] == "0.000"
    pub = published_material(client, h)
    r = client.patch(
        f"/materials/{pub['id']}", json={"version": pub["version"], "total_kg": "0.000"}, headers=h
    )
    assert r.status_code == 422
    e = r.json()["error"]["details"]["errors"][0]
    assert (e["field"], e["code"]) == ("total_kg", "out_of_range")


def test_active_obligations_block_characteristics(client, seller):
    h = seller["headers"]
    pub = published_material(client, h)
    _sql(
        "update materials set held_kg=20, available_kg=100.5, status='partially_allocated' where id=:i",
        i=pub["id"],
    )
    v = pub["version"]
    r = client.patch(
        f"/materials/{pub['id']}",
        json={"version": v, "condition": "worn", "total_kg": "130.000", "name": "N"},
        headers=h,
    )
    assert r.status_code == 409
    assert r.json()["error"]["code"] == "ACTIVE_OBLIGATIONS"
    assert r.json()["error"]["details"] == {"blocked_fields": ["condition", "total_kg"]}
    assert client.get(f"/materials/{pub['id']}", headers=h).json()["name"] != "N"  # nothing applied
    # allowed under obligations
    r = client.patch(
        f"/materials/{pub['id']}",
        json={"version": v, "name": "N", "price_per_kg": "50.00"},
        headers=h,
    )
    assert r.status_code == 200 and r.json()["status"] == "partially_allocated"
    # no upload while obligations exist
    assert upload(client, h, pub["id"]).status_code == 409


def test_total_kg_below_used_is_blocked(client, seller):
    h = seller["headers"]
    pub = published_material(client, h)
    _sql(
        "update materials set internally_used_kg=50, available_kg=70.5, status='partially_allocated' where id=:i",
        i=pub["id"],
    )
    r = client.patch(
        f"/materials/{pub['id']}", json={"version": pub["version"], "total_kg": "40.000"}, headers=h
    )
    assert r.status_code == 409 and r.json()["error"]["code"] == "ACTIVE_OBLIGATIONS"
    r = client.patch(
        f"/materials/{pub['id']}", json={"version": pub["version"], "total_kg": "60.000"}, headers=h
    )
    assert r.status_code == 200
    assert r.json()["balance"]["available_kg"] == "10.000"


def test_balance_invariant_holds_in_db_constraint():
    import sqlalchemy.exc

    engine = create_engine(__import__("os").environ["DATABASE_URL"])
    try:
        with engine.begin() as c:
            c.execute(
                text(
                    "insert into organizations (id,name,city,activity_type,created_at,updated_at) values ('00000000-0000-0000-0000-000000000001','o','c','other',now(),now())"
                )
            )
            try:
                c.execute(
                    text(
                        "insert into materials (id,organization_id,name,status,total_kg,available_kg,held_kg,"
                        "transferred_kg,internally_used_kg,version,created_at,updated_at) values "
                        "('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','m','draft',10,5,1,1,1,1,now(),now())"
                    )
                )
                raise AssertionError("balance check did not fire")
            except sqlalchemy.exc.IntegrityError:
                pass
    finally:
        engine.dispose()


# ---------- confirm ----------


def test_confirm_and_repeat(client, seller):
    h = seller["headers"]
    m = new_material(client, h, composition=None)
    r = client.post(f"/materials/{m['id']}/confirm", json={"version": 1}, headers=h)
    assert r.status_code == 200
    body = r.json()
    assert body["is_confirmation_current"] is True and body["confirmed_by"] == seller["user"]["id"]
    assert body["version"] == 1 and body["composition"] is None
    r2 = client.post(f"/materials/{m['id']}/confirm", json={"version": 1}, headers=h)
    assert r2.status_code == 200 and r2.json()["confirmed_at"] == body["confirmed_at"]


def test_confirm_stale_version_and_unknown_analysis(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    client.patch(f"/materials/{m['id']}", json={"version": 1, "name": "x"}, headers=h)
    r = client.post(f"/materials/{m['id']}/confirm", json={"version": 1}, headers=h)
    assert r.status_code == 409 and r.json()["error"]["code"] == "VERSION_CONFLICT"
    r = client.post(
        f"/materials/{m['id']}/confirm",
        json={"version": 2, "analysis_id": str(uuid.uuid4())},
        headers=h,
    )
    assert r.status_code == 409
    assert r.json()["error"]["details"]["reason"] == "ANALYSIS_NOT_FOUND_FOR_MATERIAL"
    assert client.get(f"/materials/{m['id']}", headers=h).json()["is_confirmation_current"] is False


def test_characteristic_change_resets_confirmation_name_change_does_not(client, seller):
    h = seller["headers"]
    m = ready_material(client, h)
    r = client.patch(
        f"/materials/{m['id']}", json={"version": m["version"], "name": "Другое имя"}, headers=h
    )
    assert r.json()["is_confirmation_current"] is True and r.json()["version"] == m["version"] + 1
    v = r.json()["version"]
    r = client.patch(f"/materials/{m['id']}", json={"version": v, "scrap_size": "10x10"}, headers=h)
    assert r.json()["is_confirmation_current"] is False
    assert r.json()["confirmed_at"] is None and r.json()["confirmed_by"] is None


# ---------- publish ----------


def test_publish_missing_lists_all_requirements(client, seller):
    h = seller["headers"]
    m = client.post("/materials", json={"name": "Пустой"}, headers=h).json()
    r = client.post(f"/materials/{m['id']}/publish", json={"version": 1}, headers=h)
    assert r.status_code == 422
    err = r.json()["error"]
    assert err["code"] == "PUBLISH_REQUIREMENTS_NOT_MET"
    expected = ["material_type", "total_kg", "condition", "city", "images", "confirmation"]
    assert err["details"]["missing"] == expected
    assert [e["field"] for e in err["details"]["errors"]] == expected
    assert client.get(f"/materials/{m['id']}", headers=h).json()["status"] == "draft"


def test_publish_requires_mass_strictly_positive(client, seller):
    h = seller["headers"]
    m = ready_material(client, h)
    r = client.patch(
        f"/materials/{m['id']}", json={"version": m["version"], "total_kg": "0.000"}, headers=h
    )
    v = r.json()["version"]
    client.post(f"/materials/{m['id']}/confirm", json={"version": v}, headers=h)
    r = client.post(f"/materials/{m['id']}/publish", json={"version": v}, headers=h)
    assert r.status_code == 422
    assert r.json()["error"]["details"]["missing"] == ["total_kg"]


def test_publish_requires_current_confirmation(client, seller):
    h = seller["headers"]
    m = ready_material(client, h)
    r = client.patch(
        f"/materials/{m['id']}", json={"version": m["version"], "city": "Ош"}, headers=h
    )
    r = client.post(
        f"/materials/{m['id']}/publish", json={"version": r.json()["version"]}, headers=h
    )
    assert r.status_code == 422 and r.json()["error"]["details"]["missing"] == ["confirmation"]


def test_publish_requires_photo(client, seller):
    h = seller["headers"]
    m = new_material(client, h)
    client.post(f"/materials/{m['id']}/confirm", json={"version": 1}, headers=h)
    r = client.post(f"/materials/{m['id']}/publish", json={"version": 1}, headers=h)
    assert r.status_code == 422 and r.json()["error"]["details"]["missing"] == ["images"]


def test_publish_success_idempotent_and_version_rules(client, seller):
    h = seller["headers"]
    m = ready_material(client, h)
    r = client.post(f"/materials/{m['id']}/publish", json={"version": m["version"]}, headers=h)
    assert r.status_code == 200
    pub = r.json()
    assert pub["status"] == "available" and pub["version"] == m["version"]
    assert pub["balance"]["available_kg"] == "120.500"
    again = client.post(f"/materials/{m['id']}/publish", json={"version": m["version"]}, headers=h)
    assert again.status_code == 200 and again.json() == pub  # updated_at unchanged too
    stale = client.post(
        f"/materials/{m['id']}/publish", json={"version": m["version"] - 1}, headers=h
    )
    assert stale.status_code == 409 and stale.json()["error"]["code"] == "VERSION_CONFLICT"


def test_editing_published_returns_to_draft(client, seller):
    h = seller["headers"]
    pub = published_material(client, h)
    r = client.patch(
        f"/materials/{pub['id']}", json={"version": pub["version"], "condition": "worn"}, headers=h
    )
    assert r.json()["status"] == "draft" and r.json()["is_confirmation_current"] is False
    # name-only edit keeps the published status
    pub2 = published_material(client, h)
    r = client.patch(
        f"/materials/{pub2['id']}", json={"version": pub2["version"], "name": "Н"}, headers=h
    )
    assert r.json()["status"] == "available"


def test_publish_missing_version_422(client, seller):
    m = ready_material(client, seller["headers"])
    r = client.post(f"/materials/{m['id']}/publish", json={}, headers=seller["headers"])
    assert r.status_code == 422 and r.json()["error"]["details"]["errors"][0]["field"] == "version"


# ---------- archive ----------


def test_archive_flow_and_repeat_semantics(client, seller):
    h = seller["headers"]
    pub = published_material(client, h)
    r = client.post(f"/materials/{pub['id']}/archive", json={"version": pub["version"]}, headers=h)
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "archived" and body["version"] == pub["version"] + 1
    assert body["confirmed_at"] is not None
    ok = client.post(
        f"/materials/{pub['id']}/archive", json={"version": body["version"]}, headers=h
    )
    assert ok.status_code == 200 and ok.json() == body
    stale = client.post(
        f"/materials/{pub['id']}/archive", json={"version": pub["version"]}, headers=h
    )
    assert stale.status_code == 409 and stale.json()["error"]["code"] == "VERSION_CONFLICT"
    # no way back and no edits
    r = client.post(f"/materials/{pub['id']}/publish", json={"version": body["version"]}, headers=h)
    assert r.status_code == 409 and r.json()["error"]["code"] == "INVALID_TRANSITION"
    assert r.json()["error"]["details"] == {"from": "archived", "action": "publish"}
    r = client.patch(
        f"/materials/{pub['id']}", json={"version": body["version"], "name": "x"}, headers=h
    )
    assert r.status_code == 409 and r.json()["error"]["code"] == "INVALID_TRANSITION"
    assert upload(client, h, pub["id"]).status_code == 409


def test_archive_blocked_by_held_mass(client, seller):
    h = seller["headers"]
    pub = published_material(client, h)
    _sql(
        "update materials set held_kg=20, available_kg=100.5, status='partially_allocated' where id=:i",
        i=pub["id"],
    )
    r = client.post(f"/materials/{pub['id']}/archive", json={"version": pub["version"]}, headers=h)
    assert r.status_code == 409
    assert r.json()["error"]["code"] == "ACTIVE_OBLIGATIONS"
    assert r.json()["error"]["details"] == {"held_kg": "20.000", "reason": "HELD_RESERVATIONS"}
    _sql(
        "update materials set held_kg=0, transferred_kg=20, status='partially_allocated' where id=:i",
        i=pub["id"],
    )
    r = client.post(f"/materials/{pub['id']}/archive", json={"version": pub["version"]}, headers=h)
    assert r.status_code == 200  # transferred mass does not block archiving


def test_lifecycle_rate_limit(make_app, monkeypatch, seller):
    from fastapi.testclient import TestClient

    monkeypatch.setenv("RATE_LIMIT_LIFECYCLE_PER_USER", "2")
    with TestClient(make_app(), raise_server_exceptions=False) as c:
        m = new_material(c, seller["headers"])
        codes = [
            c.post(f"/materials/{m['id']}/publish", json={"version": 1}, headers=seller["headers"])
            for _ in range(3)
        ]
        assert [r.status_code for r in codes] == [422, 422, 429]
        assert int(codes[2].headers["retry-after"]) >= 1
        assert codes[2].json()["error"]["details"]["retry_after_seconds"] >= 1
    monkeypatch.undo()
