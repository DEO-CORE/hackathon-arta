import uuid
from typing import Annotated

from pydantic import Field, model_validator

from app.models.enums import RegisterRole, Role
from app.schemas.organization import OrganizationIn, OrganizationOut
from app.schemas.types import Email, OutModel, StrictIn, trimmed


class PersonalProfile(StrictIn):
    name: trimmed(200)
    city: trimmed(100)


class RegisterIn(StrictIn):
    email: Email
    password: Annotated[str, Field(min_length=10, max_length=128)]
    role: RegisterRole
    organization: OrganizationIn | None = None
    profile: PersonalProfile | None = None

    @model_validator(mode="after")
    def validate_identity(self):
        if self.role.value == "enterprise" and (
            self.organization is None or self.profile is not None
        ):
            raise ValueError("Enterprise requires organization, not personal profile")
        if self.role.value == "buyer" and ((self.organization is None) == (self.profile is None)):
            raise ValueError("Buyer requires exactly one of profile or organization")
        return self


class LoginIn(StrictIn):
    email: Annotated[str, Field(min_length=1, max_length=254)]
    password: Annotated[str, Field(min_length=1, max_length=128)]


class UserOut(OutModel):
    id: uuid.UUID
    email: str
    role: Role
    organization_id: uuid.UUID | None
    profile_name: str | None = None
    profile_city: str | None = None
    active: bool


class UserWithOrganizationOut(OutModel):
    user: UserOut
    organization: OrganizationOut | None


class TokenOut(OutModel):
    access_token: str
    token_type: str = "bearer"  # noqa: S105
    expires_in: int
    user: UserOut
