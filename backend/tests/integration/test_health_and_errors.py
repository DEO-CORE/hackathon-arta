import uuid


def test_health_has_no_secrets_and_request_id(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}
    uuid.UUID(r.headers["x-request-id"])


def test_unknown_route_uses_error_envelope(client):
    r = client.get("/nope")
    assert r.status_code == 404
    err = r.json()["error"]
    assert err["code"] == "NOT_FOUND"
    assert err["request_id"] == r.headers["x-request-id"]
    assert set(err) == {"code", "message", "details", "request_id"}


def test_protected_route_without_token_is_401_envelope(client):
    r = client.get("/organizations/me")
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "UNAUTHENTICATED"


def test_json_body_over_64kb_is_422(client):
    r = client.post(
        "/auth/login",
        content=b'{"email":"' + b"a" * 70_000 + b'"}',
        headers={"content-type": "application/json"},
    )
    assert r.status_code == 422
    assert r.json()["error"]["details"]["errors"][0] == {
        "field": "",
        "code": "too_long",
        "message": "Тело запроса слишком велико.",
    }


def test_unhandled_exception_is_500_envelope_without_traceback(make_app):
    from fastapi.testclient import TestClient

    app = make_app()

    @app.get("/boom")
    def boom():
        raise RuntimeError("secret internals")

    with TestClient(app, raise_server_exceptions=False) as c:
        r = c.get("/boom")
    assert r.status_code == 500
    assert r.json()["error"]["code"] == "INTERNAL_ERROR"
    assert "secret" not in r.text
    assert r.headers["x-request-id"] == r.json()["error"]["request_id"]
