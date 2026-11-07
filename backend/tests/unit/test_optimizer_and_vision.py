import json
from decimal import Decimal as D
from pathlib import Path

import pytest
from pydantic import ValidationError

from app.schemas.vision import VisionModelOutput
from app.services.optimizer import Edge, solve, validate_plan, value


def edge(material, option, upper, minimum, price):
    return Edge(material, option, "sale", option, D(upper), D(minimum), D(price), D(0), 100)


def test_shared_capacity_minimum_and_baseline():
    edges = [
        edge("a", "x", "10", "6", "2"),
        edge("a", "y", "10", "1", "1"),
        edge("b", "x", "10", "6", "5"),
    ]
    stock, demand = {"a": D(10), "b": D(10)}, {"x": D(10), "y": D(10)}
    quantities, baseline, status = solve(edges, stock, demand, 3)
    assert status == "optimal"
    assert quantities == [D(0), D(10), D(10)]
    assert value(edges, quantities) >= value(edges, baseline)
    assert validate_plan(edges, quantities, stock, demand) == {"a": D(0), "b": D(0)}


def test_fractional_mass_and_invalid_plan():
    edges = [edge("a", "x", "0.003", "0.002", "3")]
    stock, demand = {"a": D(".003")}, {"x": D(".002")}
    quantities, _, _ = solve(edges, stock, demand, 3)
    assert quantities == [D(".002")]
    with pytest.raises(ValueError):
        validate_plan(edges, [D(".003")], stock, demand)


def test_vision_forbids_inferred_composition_and_inconsistent_confidence():
    raw = json.loads((Path("app/fixtures/demo-analysis.json")).read_text())["result"]
    VisionModelOutput.model_validate(raw)
    with pytest.raises(ValidationError):
        VisionModelOutput.model_validate(raw | {"composition": "cotton"})
    raw["visual_features"]["color"]["primary"] = None
    raw["visual_features"]["color"]["confidence"] = "high"
    with pytest.raises(ValidationError):
        VisionModelOutput.model_validate(raw)


def test_large_lots_do_not_hit_semi_integer_solver_cap():
    edges = [edge("a", "x", "1000", "200", "3")]
    quantities, _, status = solve(edges, {"a": D(1000)}, {"x": D(1000)}, 3)
    assert status == "optimal"
    assert quantities == [D(1000)]


def test_timeout_without_incumbent_uses_feasible_baseline(monkeypatch):
    from types import SimpleNamespace

    from app.services import optimizer

    monkeypatch.setattr(optimizer, "milp", lambda **kwargs: SimpleNamespace(x=None, status=1))
    edges = [edge("a", "x", "10", "2", "3")]
    quantities, baseline, status = solve(edges, {"a": D(10)}, {"x": D(10)}, 3)
    assert status == "heuristic"
    assert quantities == baseline == [D(10)]


def test_vision_configuration_cannot_silently_enable_mock():
    from app.core.config import Settings

    base = dict(database_url="postgresql://localhost/test", jwt_secret="x" * 40)
    with pytest.raises(ValidationError):
        Settings(**base, vision_provider="mock", demo_mode=False)
    with pytest.raises(ValidationError):
        Settings(**base, app_env="production", vision_provider="disabled")
    with pytest.raises(ValidationError):
        Settings(**base, vision_provider="http_json")
    assert Settings(**base, vision_provider="mock", demo_mode=True).demo_mode
