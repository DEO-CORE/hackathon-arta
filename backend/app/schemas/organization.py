import uuid
from typing import Self

from pydantic import model_validator
from pydantic_core import PydanticCustomError

from app.models.enums import ActivityType, OrganizationKind
from app.schemas.types import OutModel, StrictIn, UtcDateTime, trimmed


class ContactInfo(StrictIn):
    contact_name: trimmed(200) | None = None
    contact_phone: trimmed(200) | None = None
    contact_email: trimmed(200) | None = None


class ContactInfoOut(OutModel):
    contact_name: str | None = None
    contact_phone: str | None = None
    contact_email: str | None = None


class OrganizationIn(StrictIn):
    name: trimmed(200)
    city: trimmed(100)
    activity_type: ActivityType
    contacts: ContactInfo | None = None


class OrganizationPatchIn(StrictIn):
    name: trimmed(200) = None  # type: ignore[assignment]
    city: trimmed(100) = None  # type: ignore[assignment]
    activity_type: ActivityType = None  # type: ignore[assignment]
    contacts: ContactInfo = None  # type: ignore[assignment]

    @model_validator(mode="after")
    def _at_least_one(self) -> Self:
        if not self.model_fields_set:
            raise PydanticCustomError("no_changes", "at least one field required")
        return self


class OrganizationOut(OutModel):
    id: uuid.UUID
    name: str
    city: str
    activity_type: ActivityType
    kind: OrganizationKind | None = None
    contacts: ContactInfoOut
    created_at: UtcDateTime


def organization_out(org) -> OrganizationOut:
    return OrganizationOut(
        id=org.id,
        name=org.name,
        city=org.city,
        activity_type=org.activity_type,
        kind=org.kind,
        contacts=ContactInfoOut(
            contact_name=org.contact_name,
            contact_phone=org.contact_phone,
            contact_email=org.contact_email,
        ),
        created_at=org.created_at,
    )
