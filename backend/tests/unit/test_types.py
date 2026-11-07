from decimal import Decimal

import pytest
from pydantic import TypeAdapter, ValidationError

from app.schemas.types import Mass, MassOut, Money, MoneyOut


@pytest.mark.parametrize(
    ("raw", "expected"),
    [("0", "0.000"), ("12.5", "12.500"), ("999999999.999", "999999999.999"), (" 3 ", "3.000")],
)
def test_mass_accepts(raw, expected):
    d = TypeAdapter(Mass).validate_python(raw)
    assert d == Decimal(expected) and f"{d:.3f}" == expected


@pytest.mark.parametrize(
    ("raw", "code"),
    [
        (12.5, "invalid_type"),
        (12, "invalid_type"),
        (True, "invalid_type"),
        (None, "invalid_type"),
        ("1.2345", "too_many_decimals"),
        ("-0.5", "out_of_range"),
        ("1000000000", "out_of_range"),
        ("1e3", "invalid_decimal"),
        ("NaN", "invalid_decimal"),
        ("", "invalid_decimal"),
        ("1,5", "invalid_decimal"),
    ],
)
def test_mass_rejects(raw, code):
    with pytest.raises(ValidationError) as e:
        TypeAdapter(Mass).validate_python(raw)
    assert e.value.errors()[0]["type"] == code


def test_money_two_places_and_serialization():
    assert TypeAdapter(Money).validate_python("45") == Decimal("45.00")
    with pytest.raises(ValidationError):
        TypeAdapter(Money).validate_python("45.001")
    assert TypeAdapter(MoneyOut).dump_python(Decimal("45"), mode="json") == "45.00"
    assert TypeAdapter(MassOut).dump_python(Decimal("0"), mode="json") == "0.000"
