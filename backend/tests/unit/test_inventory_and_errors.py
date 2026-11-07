from decimal import Decimal as D

from app.core.errors import map_validation_errors
from app.models import Material
from app.models.enums import MaterialStatus as S
from app.services import inventory


def _m(total, avail, held=0, transferred=0, used=0, status=S.available) -> Material:
    return Material(
        total_kg=D(total),
        available_kg=D(avail),
        held_kg=D(held),
        transferred_kg=D(transferred),
        internally_used_kg=D(used),
        status=status,
    )


def test_status_derivation_from_balances():
    assert inventory.derive_published_status(_m(100, 100)) == S.available
    assert inventory.derive_published_status(_m(100, 40, held=60)) == S.partially_allocated
    assert inventory.derive_published_status(_m(100, 0, held=100)) == S.reserved
    assert inventory.derive_published_status(_m(100, 0, transferred=60, used=40)) == S.completed


def test_draft_and_archived_are_not_overridden():
    for st in (S.draft, S.archived):
        m = _m(100, 100, status=st)
        inventory.refresh_status(m)
        assert m.status == st


def test_balance_consistency_check():
    assert inventory.balance_is_consistent(_m(10, 4, 3, 2, 1))
    assert not inventory.balance_is_consistent(_m(10, 4, 3, 2, 2))
    assert not inventory.balance_is_consistent(_m(10, 11, -1, 0, 0))


def test_validation_error_mapping_drops_prefix_and_values():
    errs = map_validation_errors(
        [
            {"type": "missing", "loc": ("body", "organization", "name"), "input": {}},
            {"type": "extra_forbidden", "loc": ("body", "x"), "input": "secret-value"},
            {"type": "string_type", "loc": ("body", "name"), "input": None},
            {"type": "int_parsing", "loc": ("query", "page"), "input": "abc"},
            {"type": "greater_than_equal", "loc": ("query", "page_size"), "input": 0},
            {"type": "too_many_decimals", "loc": ("body", "uses", 1), "input": "1"},
        ]
    )
    assert [(e["field"], e["code"]) for e in errs] == [
        ("organization.name", "required"),
        ("x", "extra_forbidden"),
        ("name", "null_not_allowed"),
        ("page", "invalid_type"),
        ("page_size", "out_of_range"),
        ("uses.1", "too_many_decimals"),
    ]
    assert "secret-value" not in str(errs)
