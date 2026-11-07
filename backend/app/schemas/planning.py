from typing import Literal
from uuid import UUID

from pydantic import Field, model_validator

from app.schemas.types import Mass, Money, OutModel, StrictIn, UtcDateTime
from app.schemas.vision import VisionModelOutput


class MaterialReference(StrictIn):
    material_id: UUID


class MatchIn(MaterialReference):
    limit: int = Field(20, ge=1, le=50)


class DirectionAssumption(StrictIn):
    value_per_kg: Money
    cost_per_kg: Money
    capacity_kg: Mass


class Assumptions(StrictIn):
    internal_use: DirectionAssumption | None = None
    recycling: DirectionAssumption | None = None
    delivery_cost_per_kg: Money | None = None


class OptimizationIn(StrictIn):
    material_ids: list[UUID] = Field(min_length=1, max_length=20)
    assumptions: Assumptions | None = None

    @model_validator(mode="after")
    def unique(self):
        if len(set(self.material_ids)) != len(self.material_ids):
            raise ValueError("material_ids must be unique")
        return self


class AnalysisAccepted(OutModel):
    analysis_id: UUID
    status: Literal["pending", "running"]
    input_version: int


class AnalysisOut(OutModel):
    id: UUID
    material_id: UUID
    status: Literal["pending", "running", "succeeded", "failed", "interrupted"]
    input_version: int
    is_current: bool
    mode: Literal["live", "mock", "fallback"] | None
    requires_confirmation: Literal[True]
    schema_version: str
    provider: str | None
    model: str | None
    result: VisionModelOutput | None
    error_code: str | None
    confirmed_at: UtcDateTime | None
    confirmed_by: UUID | None
    created_at: UtcDateTime
    updated_at: UtcDateTime


class MatchItem(OutModel):
    requirement_id: UUID
    organization_name: str
    score: int
    components: dict[str, int]
    reasons: list[str]
    possible_kg: str
    city: str | None


class ExcludedItem(OutModel):
    requirement_id: UUID
    reason_codes: list[str]
    reasons: list[str]


class MatchOut(OutModel):
    material_id: UUID
    material_version: int
    rules_version: str
    matches: list[MatchItem]
    excluded: list[ExcludedItem]


class AllocationOut(OutModel):
    material_id: UUID
    direction: Literal["internal_use", "sale", "recycling"]
    requirement_id: UUID | None
    quantity_kg: str
    unit_value_kgs: str
    unit_cost_kgs: str
    net_value_kgs: str
    explanation: str


class RemainderOut(OutModel):
    material_id: UUID
    remainder_kg: str


class InputVersionOut(OutModel):
    material_id: UUID
    version: int


class BaselineOut(OutModel):
    method: str
    value_kgs: str


class OptimizationOut(OutModel):
    id: UUID
    status: Literal["optimal", "feasible", "infeasible", "timeout", "error", "heuristic"]
    method: str
    algorithm_version: str
    rules_version: str
    label: Literal["expected"]
    objective_kgs: str
    baseline: BaselineOut
    delta_vs_baseline_kgs: str
    allocations: list[AllocationOut]
    remainder: list[RemainderOut]
    input_versions: list[InputVersionOut]
    assumptions: dict
    excluded_options: list[dict]
    solve_time_ms: int
    is_stale: bool
    created_at: UtcDateTime


class ForecastOut(OutModel):
    run_id: UUID
    label: Literal["expected"]
    expected_net_value_kgs: str
    expected_remainder_kg: str
    is_stale: bool


class EnterpriseSummary(OutModel):
    role_view: Literal["enterprise"]
    registered_kg: str
    available_kg: str
    distributed_kg: str
    internally_used_kg: str
    confirmed_reuse_kg: str
    revenue_kgs: str
    allocation_efficiency_pct: str
    forecast: ForecastOut | None
    is_demo: bool
    generated_at: UtcDateTime


class BuyerSummary(OutModel):
    role_view: Literal["buyer"]
    received_kg: str
    confirmed_reuse_kg: str
    spent_kgs: str
    active_reservations_count: int
    is_demo: bool
    generated_at: UtcDateTime
