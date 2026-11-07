import uuid
from typing import Annotated

from pydantic import Field

from app.models.enums import RegisterRole, Role
from app.schemas.organization import OrganizationIn, OrganizationOut
from app.schemas.types import Email, OutModel, StrictIn


class RegisterIn(StrictIn):
    email: Email
    password: Annotated[str, Field(min_length=10, max_length=128)]
    role: RegisterRole
    organization: OrganizationIn


class LoginIn(StrictIn):
    email: Annotated[str, Field(min_length=1, max_length=254)]
    password: Annotated[str, Field(min_length=1, max_length=128)]


class UserOut(OutModel):
    id: uuid.UUID
    email: str
    role: Role
    organization_id: uuid.UUID
    active: bool


class UserWithOrganizationOut(OutModel):
    user: UserOut
    organization: OrganizationOut


class TokenOut(OutModel):
    access_token: str
    token_type: str = "bearer"  # noqa: S105
    expires_in: int
    user: UserOut
