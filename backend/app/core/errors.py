from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.request_context import get_request_id

# (status, default Russian message) per error code from docs/api.md 1.2.
_DEFAULT_MESSAGES = {
    "UNAUTHENTICATED": "Требуется вход.",
    "INVALID_CREDENTIALS": "Неверный email или пароль.",
    "ACCOUNT_DISABLED": "Учётная запись отключена. Обратитесь в поддержку.",
    "FORBIDDEN": "Действие недоступно для вашей роли.",
    "NOT_FOUND": "Объект не найден.",
    "VERSION_CONFLICT": "Данные устарели. Обновите карточку.",
    "INVALID_TRANSITION": "Действие недопустимо в текущем статусе.",
    "ACTIVE_OBLIGATIONS": "Есть активные обязательства по партии.",
    "IMAGE_LIMIT_REACHED": "Достигнут лимит фото на партии.",
    "PRECONDITION_FAILED": "Не выполнено условие операции.",
    "EMAIL_ALREADY_REGISTERED": "Этот email уже зарегистрирован.",
    "VALIDATION_ERROR": "Проверьте заполненные поля.",
    "PUBLISH_REQUIREMENTS_NOT_MET": "Для публикации заполнены не все данные.",
    "UNSUPPORTED_IMAGE": "Файл не подходит: нужен JPEG, PNG или WebP в пределах лимитов.",
    "RATE_LIMITED": "Слишком много запросов. Повторите позже.",
    "INTERNAL_ERROR": "Внутренняя ошибка сервера.",
}


class AppError(Exception):
    def __init__(
        self,
        status_code: int,
        code: str,
        message: str | None = None,
        details: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(code)
        self.status_code = status_code
        self.code = code
        self.message = message or _DEFAULT_MESSAGES.get(code, code)
        self.details = details
        self.headers = headers or {}


def error_body(code: str, message: str, details: dict[str, Any] | None) -> dict[str, Any]:
    return {
        "error": {
            "code": code,
            "message": message,
            "details": details,
            "request_id": get_request_id(),
        }
    }


def error_response(
    status_code: int,
    code: str,
    message: str | None = None,
    details: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
) -> JSONResponse:
    resp = JSONResponse(
        status_code=status_code,
        content=error_body(code, message or _DEFAULT_MESSAGES.get(code, code), details),
        headers=headers,
    )
    return resp


def not_found() -> AppError:
    return AppError(404, "NOT_FOUND")


def validation_error(field: str, code: str, message: str) -> AppError:
    return AppError(
        422,
        "VALIDATION_ERROR",
        details={"errors": [{"field": field, "code": code, "message": message}]},
    )


_KNOWN_CODES = {
    "required",
    "null_not_allowed",
    "invalid_type",
    "invalid_value",
    "too_short",
    "too_long",
    "out_of_range",
    "invalid_decimal",
    "too_many_decimals",
    "extra_forbidden",
    "no_changes",
    "mass_must_be_positive",
}

_RU = {
    "required": "Поле обязательно.",
    "null_not_allowed": "Значение не может быть пустым.",
    "invalid_type": "Неверный тип значения.",
    "invalid_value": "Недопустимое значение.",
    "too_short": "Слишком короткое значение.",
    "too_long": "Слишком длинное значение.",
    "out_of_range": "Значение вне допустимого диапазона.",
    "invalid_decimal": 'Укажите число в виде строки, например "12.500".',
    "too_many_decimals": "Слишком много знаков после точки.",
    "extra_forbidden": "Это поле нельзя передавать.",
    "no_changes": "Укажите хотя бы одно изменяемое поле.",
    "mass_must_be_positive": "Масса должна быть больше нуля.",
}

_TYPE_MAP = {
    "missing": "required",
    "extra_forbidden": "extra_forbidden",
    "string_too_short": "too_short",
    "too_short": "too_short",
    "string_too_long": "too_long",
    "too_long": "too_long",
    "greater_than_equal": "out_of_range",
    "greater_than": "out_of_range",
    "less_than_equal": "out_of_range",
    "less_than": "out_of_range",
    "enum": "invalid_value",
    "literal_error": "invalid_value",
    "string_pattern_mismatch": "invalid_value",
    "value_error": "invalid_value",
}


def _field_path(loc: tuple[Any, ...]) -> str:
    parts = list(loc)
    if parts and parts[0] in ("body", "query", "header", "form", "path", "cookie"):
        parts = parts[1:]
    return ".".join(str(p) for p in parts)


def map_validation_errors(errors: list[dict[str, Any]]) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for err in errors:
        etype = str(err.get("type", ""))
        if etype in _KNOWN_CODES:
            code = etype
        elif etype in _TYPE_MAP:
            code = _TYPE_MAP[etype]
        elif err.get("input") is None:
            code = "null_not_allowed"
        else:
            code = "invalid_type"
        # Never echo the client's value back.
        out.append(
            {"field": _field_path(tuple(err.get("loc", ()))), "code": code, "message": _RU[code]}
        )
    return out


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error(_: Request, exc: AppError) -> JSONResponse:
        return error_response(exc.status_code, exc.code, exc.message, exc.details, exc.headers)

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        errors = map_validation_errors(list(exc.errors()))
        return error_response(422, "VALIDATION_ERROR", details={"errors": errors})

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        if exc.status_code == 404:
            return error_response(404, "NOT_FOUND")
        if exc.status_code == 405:
            return error_response(405, "METHOD_NOT_ALLOWED", "Метод не поддерживается.")
        return error_response(exc.status_code, "HTTP_ERROR", "Запрос не может быть обработан.")

    @app.exception_handler(Exception)
    async def _unhandled(_: Request, __: Exception) -> JSONResponse:
        return error_response(500, "INTERNAL_ERROR")
