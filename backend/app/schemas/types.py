"""Shared Pydantic types: decimal strings for mass/money, UTC timestamps (api.md section 1)."""

import re
from datetime import UTC, datetime
from decimal import Decimal, InvalidOperation
from typing import Annotated, Any

from pydantic import (
    AfterValidator,
    BaseModel,
    BeforeValidator,
    ConfigDict,
    PlainSerializer,
    StringConstraints,
)
from pydantic_core import PydanticCustomError

_PLAIN_DECIMAL = re.compile(r"^\d+(\.\d+)?$")


def _decimal_parser(places: int, max_int_digits: int):
    def parse(value: Any) -> Decimal:
        if isinstance(value, bool) or not isinstance(value, str):
            # JSON numbers are rejected on purpose: floats must not carry money or mass.
            raise PydanticCustomError("invalid_type", "decimal string expected")
        s = value.strip()
        if s.startswith("-") and _PLAIN_DECIMAL.match(s[1:]):
            raise PydanticCustomError("out_of_range", "must be >= 0")
        if not _PLAIN_DECIMAL.match(s):
            raise PydanticCustomError("invalid_decimal", "not a decimal")
        try:
            d = Decimal(s)
        except InvalidOperation:
            raise PydanticCustomError("invalid_decimal", "not a decimal") from None
        frac = s.split(".", 1)[1] if "." in s else ""
        if len(frac) > places:
            raise PydanticCustomError("too_many_decimals", "too many decimals")
        if len(s.split(".", 1)[0].lstrip("0") or "0") > max_int_digits:
            raise PydanticCustomError("out_of_range", "too large")
        return d.quantize(Decimal(1).scaleb(-places))

    return parse


def parse_mass(value: Any) -> Decimal:
    return _decimal_parser(3, 9)(value)


def parse_money(value: Any) -> Decimal:
    return _decimal_parser(2, 12)(value)


Mass = Annotated[Decimal, BeforeValidator(parse_mass)]
Money = Annotated[Decimal, BeforeValidator(parse_money)]

MassOut = Annotated[
    Decimal, PlainSerializer(lambda d: f"{d:.3f}", return_type=str, when_used="always")
]
MoneyOut = Annotated[
    Decimal, PlainSerializer(lambda d: f"{d:.2f}", return_type=str, when_used="always")
]


def _to_utc_z(dt: datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC).replace(microsecond=0).strftime("%Y-%m-%dT%H:%M:%SZ")


UtcDateTime = Annotated[datetime, PlainSerializer(_to_utc_z, return_type=str, when_used="always")]

Trimmed = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1)]


def trimmed(max_length: int):
    return Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=1, max_length=max_length)
    ]


def _check_email(v: str) -> str:
    v = v.strip().lower()
    if len(v) > 254 or not re.fullmatch(r"[^@\s]+@[^@\s.]+(\.[^@\s.]+)+", v):
        raise PydanticCustomError("invalid_value", "invalid email")
    return v


Email = Annotated[str, AfterValidator(_check_email)]


class StrictIn(BaseModel):
    """Base for request bodies: unknown fields are rejected (422 extra_forbidden)."""

    model_config = ConfigDict(extra="forbid")


class OutModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)
