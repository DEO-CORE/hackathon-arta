import uuid
from datetime import datetime
from typing import Annotated

from pydantic import Field

from app.models.enums import MembershipStatus, OrganizationKind, OrgRole, RegisterRole, Role
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
    email_confirmed: bool
    email_confirmed_at: datetime | None


class UserWithOrganizationOut(OutModel):
    user: UserOut
    organization: OrganizationOut


class TokenOut(OutModel):
    access_token: str
    token_type: str = "bearer"  # noqa: S105
    expires_in: int
    user: UserOut


class EmailCodeSendIn(StrictIn):
    email: Email


class EmailCodeSendOut(OutModel):
    status: str = "accepted"
    resend_after_seconds: int


class EmailCodeVerifyIn(StrictIn):
    email: Email
    # Format (6 digits; 4 only for the demo code) is checked in the service against settings.
    code: Annotated[str, Field(max_length=16)]


class EmailVerifiedOut(OutModel):
    user: UserOut


class MembershipOut(OutModel):
    organization_id: uuid.UUID
    role: OrgRole
    status: MembershipStatus


class MeOut(OutModel):
    user: UserOut
    organization: OrganizationOut
    organization_kind: OrganizationKind | None
    membership: MembershipOut
    default_organization_id: uuid.UUID | None
    permissions: list[str]
