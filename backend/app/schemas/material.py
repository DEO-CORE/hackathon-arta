import uuid
from decimal import Decimal
from typing import Annotated, Self

from pydantic import BaseModel, Field, model_validator
from pydantic_core import PydanticCustomError

from app.models.enums import MaterialCondition, MaterialStatus, MaterialType
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

Version = Annotated[int, Field(strict=True, ge=1)]

# Fields that are input characteristics: changing them resets confirmation (api.md section 4).
CHARACTERISTIC_FIELDS = (
    "description",
    "material_type",
    "composition",
    "scrap_size",
    "condition",
    "city",
    "total_kg",
)
PATCHABLE_FIELDS = ("name", "price_per_kg", *CHARACTERISTIC_FIELDS)


class MaterialCreateIn(StrictIn):
    name: trimmed(200)
    material_type: MaterialType | None = None
    description: trimmed(1000) | None = None
    composition: trimmed(200) | None = None
    scrap_size: trimmed(100) | None = None
    condition: MaterialCondition | None = None
    price_per_kg: Money | None = None
    city: trimmed(100) | None = None
    total_kg: Mass = Decimal("0.000")


class MaterialPatchIn(StrictIn):
    version: Version
    name: trimmed(200) = None  # type: ignore[assignment]
    material_type: MaterialType | None = None
    description: trimmed(1000) | None = None
    composition: trimmed(200) | None = None
    scrap_size: trimmed(100) | None = None
    condition: MaterialCondition | None = None
    price_per_kg: Money | None = None
    city: trimmed(100) | None = None
    total_kg: Mass = None  # type: ignore[assignment]

    @model_validator(mode="after")
    def _has_changes(self) -> Self:
        if not (self.model_fields_set & set(PATCHABLE_FIELDS)):
            raise PydanticCustomError("no_changes", "at least one field required")
        return self


class MaterialVersionIn(StrictIn):
    """Body of publish and archive."""

    version: Version


class MaterialConfirmIn(StrictIn):
    version: Version
    analysis_id: uuid.UUID | None = None


class BalanceOut(OutModel):
    total_kg: MassOut
    available_kg: MassOut
    held_kg: MassOut
    transferred_kg: MassOut
    internally_used_kg: MassOut


class MaterialImageOut(OutModel):
    id: uuid.UUID
    material_id: uuid.UUID
    mime_type: str
    size_bytes: int
    width_px: int
    height_px: int
    sort_order: int
    created_at: UtcDateTime


class MaterialOut(OutModel):
    id: uuid.UUID
    organization_id: uuid.UUID
    name: str
    material_type: MaterialType | None
    description: str | None = None
    composition: str | None
    scrap_size: str | None
    condition: MaterialCondition | None
    price_per_kg: MoneyOut | None
    city: str | None
    status: MaterialStatus
    balance: BalanceOut
    version: int
    confirmed_at: UtcDateTime | None
    confirmed_by: uuid.UUID | None
    is_confirmation_current: bool
    images: list[MaterialImageOut]
    created_at: UtcDateTime
    updated_at: UtcDateTime


class MaterialPublicOut(OutModel):
    id: uuid.UUID
    organization_id: uuid.UUID
    organization_name: str
    name: str
    material_type: MaterialType | None
    description: str | None = None
    composition: str | None
    scrap_size: str | None
    condition: MaterialCondition | None
    price_per_kg: MoneyOut | None
    city: str | None
    available_kg: MassOut
    status: MaterialStatus
    images: list[MaterialImageOut]
    version: int
    created_at: UtcDateTime


class ImageUploadOut(OutModel):
    image: MaterialImageOut
    material_version: int


class Page[T: BaseModel](BaseModel):
    items: list[T]
    page: int
    page_size: int
    total: int
