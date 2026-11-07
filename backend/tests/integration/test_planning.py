from uuid import uuid4

from tests.integration.conftest import published_material, ready_material
from tests.integration.test_commerce import requirement


def test_match_optimize_stale_and_permissions(client, seller, buyer, seller2):
    m = published_material(client, seller["headers"])
    req = requirement(client, buyer, max_kg="50.000")
    matched = client.post("/ai/match", json={"material_id": m["id"]}, headers=seller["headers"])
    assert matched.status_code == 200, matched.text
    assert matched.json()["matches"][0]["requirement_id"] == req["id"]
    response = client.post(
        "/optimization/run",
        json=dict(material_ids=[m["id"]], assumptions={"delivery_cost_per_kg": "5.00"}),
        headers=seller["headers"],
    )
    assert response.status_code == 201, response.text
    plan = response.json()
    assert plan["objective_kgs"] == "2000.00"
    assert plan["remainder"][0]["remainder_kg"] == "70.500"
    assert not plan["is_stale"]
    assert (
        client.get("/optimization/runs/" + plan["id"], headers=seller2["headers"]).status_code
        == 404
    )
    assert (
        client.get("/materials/" + m["id"], headers=seller["headers"]).json()["balance"][
            "available_kg"
        ]
        == "120.500"
    )
    client.post(
        "/materials/" + m["id"] + "/internal-use",
        json=dict(quantity_kg="1.000", basis="Образцы"),
        headers=seller["headers"] | {"Idempotency-Key": str(uuid4())},
    )
    assert client.get("/optimization/runs/" + plan["id"], headers=seller["headers"]).json()[
        "is_stale"
    ]


def test_unknown_cost_and_application_excluded(client, seller, buyer):
    m = published_material(client, seller["headers"])
    requirement(client, buyer, uses=["cleaning_rags"])
    match = client.post(
        "/ai/match", json={"material_id": m["id"]}, headers=seller["headers"]
    ).json()
    assert match["matches"] == []
    assert "UNKNOWN_APPLICATION" in match["excluded"][0]["reason_codes"]
    plan = client.post(
        "/optimization/run", json={"material_ids": [m["id"]]}, headers=seller["headers"]
    ).json()
    assert plan["allocations"] == []
    assert plan["objective_kgs"] == "0.00"


def test_ai_mock_confirmation_stale_and_isolation(client, seller, seller2, monkeypatch):
    from app.core.config import get_settings

    monkeypatch.setenv("VISION_PROVIDER", "mock")
    monkeypatch.setenv("DEMO_MODE", "true")
    get_settings.cache_clear()
    m = ready_material(client, seller["headers"])
    response = client.post("/ai/analyze", json={"material_id": m["id"]}, headers=seller["headers"])
    assert response.status_code == 202, response.text
    url = response.headers["Location"]
    job = client.get(url, headers=seller["headers"]).json()
    assert job["status"] == "succeeded", job
    assert job["mode"] == "mock" and job["requires_confirmation"] is True
    assert client.get(url, headers=seller2["headers"]).status_code == 404
    confirmed = client.post(
        "/materials/" + m["id"] + "/confirm",
        json={"version": m["version"], "analysis_id": job["id"]},
        headers=seller["headers"],
    )
    assert confirmed.status_code == 200, confirmed.text
    changed = client.patch(
        "/materials/" + m["id"],
        json={"version": m["version"], "city": "Ош"},
        headers=seller["headers"],
    ).json()
    assert not client.get(url, headers=seller["headers"]).json()["is_current"]
    assert (
        client.post(
            "/materials/" + m["id"] + "/confirm",
            json={"version": changed["version"], "analysis_id": job["id"]},
            headers=seller["headers"],
        ).status_code
        == 409
    )
    get_settings.cache_clear()


def test_disabled_ai_fails_without_blocking_manual_confirmation(client, seller):
    from tests.integration.conftest import new_material, upload

    m = new_material(client, seller["headers"])
    version = upload(client, seller["headers"], m["id"]).json()["material_version"]
    response = client.post("/ai/analyze", json={"material_id": m["id"]}, headers=seller["headers"])
    assert response.status_code == 202
    job = client.get(response.headers["Location"], headers=seller["headers"]).json()
    assert job["status"] == "failed" and job["error_code"] == "PROVIDER_UNAVAILABLE"
    assert job["result"] is None and job["mode"] is None
    m = client.get("/materials/" + m["id"], headers=seller["headers"]).json()
    assert not m["is_confirmation_current"]
    assert (
        client.post(
            "/materials/" + m["id"] + "/confirm",
            json={"version": version},
            headers=seller["headers"],
        ).status_code
        == 200
    )


def test_openapi_has_typed_backend_responses(client):
    schema = client.get("/openapi.json").json()
    for path, method, status in [
        ("/ai/analyze", "post", "202"),
        ("/ai/match", "post", "200"),
        ("/reservations", "post", "201"),
        ("/optimization/run", "post", "201"),
    ]:
        assert (
            "$ref"
            in schema["paths"][path][method]["responses"][status]["content"]["application/json"][
                "schema"
            ]
        )
