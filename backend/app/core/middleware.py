import json
import logging
import uuid

from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.errors import error_body
from app.core.request_context import get_request_id, set_request_id

logger = logging.getLogger("arta")

MAX_JSON_BODY_BYTES = 64 * 1024  # A18-6
MAX_MULTIPART_BYTES = 10 * 1024 * 1024 + 64 * 1024  # file limit plus multipart framing


class RequestContextMiddleware:
    """Assigns X-Request-ID, caps JSON bodies and turns crashes into the error envelope.

    Pure ASGI so that headers are also added to 500 responses.
    """

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        request_id = str(uuid.uuid4())
        set_request_id(request_id)
        started = False

        async def send_wrapper(message: Message) -> None:
            nonlocal started
            if message["type"] == "http.response.start":
                started = True
                headers = [h for h in message.get("headers", []) if h[0].lower() != b"x-request-id"]
                headers.append((b"x-request-id", request_id.encode()))
                message = {**message, "headers": headers}
            await send(message)

        headers_in = {k.lower(): v for k, v in scope.get("headers", [])}
        ctype = headers_in.get(b"content-type", b"")
        clen = headers_in.get(b"content-length")
        if (
            ctype.startswith(b"application/json")
            and clen is not None
            and clen.isdigit()
            and int(clen) > MAX_JSON_BODY_BYTES
        ):
            body = error_body(
                "VALIDATION_ERROR",
                "Проверьте заполненные поля.",
                {
                    "errors": [
                        {"field": "", "code": "too_long", "message": "Тело запроса слишком велико."}
                    ]
                },
            )
            await self._send_json(send_wrapper, 422, body)
            return

        if (
            ctype.startswith(b"multipart/form-data")
            and clen is not None
            and clen.isdigit()
            and int(clen) > MAX_MULTIPART_BYTES
        ):
            body = error_body(
                "UNSUPPORTED_IMAGE",
                "Файл не подходит: нужен JPEG, PNG или WebP в пределах лимитов.",
                {"reason": "bytes", "max_bytes": 10 * 1024 * 1024},
            )
            await self._send_json(send_wrapper, 422, body)
            return

        try:
            await self.app(scope, receive, send_wrapper)
        except Exception:
            logger.exception("unhandled error request_id=%s", get_request_id())
            if not started:
                await self._send_json(
                    send_wrapper,
                    500,
                    error_body("INTERNAL_ERROR", "Внутренняя ошибка сервера.", None),
                )

    @staticmethod
    async def _send_json(send: Send, status: int, body: dict) -> None:
        payload = json.dumps(body, ensure_ascii=False).encode()
        await send(
            {
                "type": "http.response.start",
                "status": status,
                "headers": [
                    (b"content-type", b"application/json"),
                    (b"content-length", str(len(payload)).encode()),
                ],
            }
        )
        await send({"type": "http.response.body", "body": payload})
