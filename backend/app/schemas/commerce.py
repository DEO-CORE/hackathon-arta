from datetime import date
from decimal import Decimal
from typing import Annotated, Literal
from uuid import UUID

from pydantic import Field, computed_field, model_validator

from app.models.enums import MaterialCondition, MaterialType
from app.schemas.material import MaterialOut
from app.schemas.types import (
    Mass,
    MassOut,
    Money,
    MoneyOut,
    OutModel,
    StrictIn,
    UtcDateTime,
    trimmed,
)

ReuseUse = Literal[
    "cleaning_rags",
    "stuffing_filling",
    "patchwork_crafts",
    "accessories_small_goods",
    "insulation_padding",
    "recycling_shredding",
    "other",
]
ReservationStatus = Literal["pending", "confirmed", "transferred", "completed", "cancelled"]
PositiveMass = Annotated[Mass, Field(gt=0)]


class RequirementCreate(StrictIn):
    material_types: list[MaterialType] = Field(min_length=1, max_length=10)
    conditions: list[MaterialCondition] = Field(min_length=1, max_length=4)
    min_kg: Mass
    max_kg: PositiveMass
    budget_per_kg: Money | None = None
    city: trimmed(100) | None = None
    uses: list[ReuseUse] = Field(default_factory=list, max_length=7)

    @model_validator(mode="after")
    def valid(self):
        if self.min_kg > self.max_kg:
            raise ValueError("min_kg must not exceed max_kg")
        for field in ("material_types", "conditions", "uses"):
            values = getattr(self, field)
            if len(values) != len(set(values)):
                raise ValueError(f"{field}: duplicates are forbidden")
        return self


class RequirementPatch(StrictIn):
    material_types: list[MaterialType] | None = Field(None, min_length=1, max_length=10)
    conditions: list[MaterialCondition] | None = Field(None, min_length=1, max_length=4)
    min_kg: Mass | None = None
    max_kg: PositiveMass | None = None
    budget_per_kg: Money | None = None
    city: trimmed(100) | None = None
    uses: list[ReuseUse] | None = Field(None, max_length=7)
    active: bool | None = None

    @model_validator(mode="after")
    def valid(self):
        if not self.model_fields_set:
            raise ValueError("at least one field is required")
        for field in self.model_fields_set - {"city", "budget_per_kg"}:
            if getattr(self, field) is None:
                raise ValueError(f"{field} cannot be null")
        return self


class RequirementPublic(OutModel):
    id: UUID
    organization_id: UUID | None
    user_id: UUID | None = None
    material_types: list[MaterialType]
    conditions: list[MaterialCondition]
    min_kg: MassOut
    max_kg: MassOut
    remaining_demand_kg: MassOut
    city: str | None
    uses: list[ReuseUse]
    active: bool
    created_at: UtcDateTime
    updated_at: UtcDateTime


class RequirementOut(RequirementPublic):
    budget_per_kg: MoneyOut | None


class ReservationCreate(StrictIn):
    purpose: trimmed(500) | None = None
    material_id: UUID
    requirement_id: UUID | None = None
    quantity_kg: PositiveMass
    agreed_price_per_kg: Money | None = None


class ReservationAction(StrictIn):
    action: Literal["confirm", "cancel", "transfer", "complete"]
    reason: trimmed(500) | None = None
    transferred_kg: PositiveMass | None = None

    @model_validator(mode="after")
    def valid(self):
        if self.transferred_kg is not None and self.action != "transfer":
            raise ValueError("transferred_kg is only allowed for transfer")
        return self


class TransactionOut(OutModel):
    id: UUID
    reservation_id: UUID
    transferred_kg: MassOut
    sale_amount_kgs: MoneyOut | None
    transfer_confirmed_at: UtcDateTime | None
    receipt_confirmed_at: UtcDateTime | None
    confirmed_reuse_kg: MassOut
    created_at: UtcDateTime


class ReservationOut(OutModel):
    id: UUID
    material_id: UUID
    material_name: str
    seller_organization_id: UUID
    buyer_organization_id: UUID | None
    buyer_user_id: UUID | None = None
    purpose: str | None = None
    requirement_id: UUID | None
    quantity_kg: MassOut
    agreed_price_per_kg: MoneyOut | None
    status: ReservationStatus
    cancel_reason: str | None
    cancelled_by_role: str | None
    transaction: TransactionOut | None
    counterparty_contacts: dict[str, str | None] | None
    created_at: UtcDateTime
    updated_at: UtcDateTime

    @computed_field
    @property
    def requested_sale_amount_kgs(self) -> MoneyOut | None:
        if self.agreed_price_per_kg is None:
            return None
        return (self.quantity_kg * self.agreed_price_per_kg).quantize(Decimal(".01"))


class InternalUse(StrictIn):
    quantity_kg: PositiveMass
    basis: trimmed(500)
    used_on: date | None = None


class ReuseConfirmation(StrictIn):
    reused_kg: PositiveMass
    basis: trimmed(500)
    reused_on: date | None = None


class InternalUseOut(OutModel):
    impact_record_id: UUID
    material: MaterialOut


class ReuseConfirmationOut(OutModel):
    impact_record_id: UUID
    transaction: TransactionOut
