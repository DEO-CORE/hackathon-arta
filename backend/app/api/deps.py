import uuid
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.errors import AppError, not_found
from app.core.permissions import permissions_for
from app.core.ratelimit import RateLimiter
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models import Material, Organization, OrganizationMembership, PlatformAdmin, User
from app.models.enums import MaterialStatus, MembershipStatus, OrganizationKind, OrgRole, Role

_bearer = HTTPBearer(auto_error=False)

DbSession = Annotated[Session, Depends(get_db)]
SettingsDep = Annotated[Settings, Depends(get_settings)]


def get_limiter(request: Request) -> RateLimiter:
    return request.app.state.limiter


Limiter = Annotated[RateLimiter, Depends(get_limiter)]


def get_current_user(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
    db: DbSession,
    settings: SettingsDep,
) -> User:
    if creds is None or creds.scheme.lower() != "bearer":
        raise AppError(401, "UNAUTHENTICATED")
    user_id = decode_access_token(creds.credentials, settings)
    user = db.get(User, user_id) if user_id else None
    if user is None or not user.active:
        raise AppError(401, "UNAUTHENTICATED")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


@dataclass(frozen=True)
class Principal:
    """Request context built from the database on every request (the token carries no rights)."""

    user: User
    organization: Organization
    membership: OrganizationMembership
    permissions: frozenset[str]

    @property
    def id(self):
        return self.user.id

    @property
    def email(self) -> str:
        return self.user.email

    @property
    def organization_id(self):
        return self.organization.id

    @property
    def kind(self) -> OrganizationKind | None:
        return self.organization.kind

    @property
    def org_role(self) -> OrgRole:
        return self.membership.role

    @property
    def role(self) -> Role:
        """Legacy side label used by services: derived from the organization, not users.role."""
        return Role.enterprise if self.kind == OrganizationKind.supplier else Role.buyer

    def can(self, permission: str) -> bool:
        return permission in self.permissions


def get_principal(user: CurrentUser, db: DbSession) -> Principal:
    """Context of the live membership: active, or pending_review (no rights at all)."""
    live = (MembershipStatus.active, MembershipStatus.pending_review)
    row = db.execute(
        select(OrganizationMembership, Organization)
        .join(Organization, Organization.id == OrganizationMembership.organization_id)
        .where(
            OrganizationMembership.user_id == user.id,
            OrganizationMembership.status.in_(live),
        )
        .order_by(
            (OrganizationMembership.status == MembershipStatus.active).desc(),
            (Organization.id == user.default_organization_id).desc(),
            OrganizationMembership.created_at,
        )
        .limit(1)
    ).first()
    if row is None:
        raise AppError(403, "NO_ACTIVE_MEMBERSHIP")
    membership, org = row
    if membership.status == MembershipStatus.pending_review:
        return Principal(user, org, membership, frozenset())
    if org.kind is None:
        raise AppError(403, "NO_ACTIVE_MEMBERSHIP")
    return Principal(
        user, org, membership, permissions_for(membership.role, org.kind, org.activity_type.value)
    )


def get_active_principal(p: Annotated[Principal, Depends(get_principal)]) -> Principal:
    if p.membership.status != MembershipStatus.active:
        raise AppError(
            403,
            "NO_ACTIVE_MEMBERSHIP",
            details={"membership_status": p.membership.status.value},
        )
    return p


# Any live membership, including pending_review: only /auth/me and GET /organizations/me.
PrincipalDep = Annotated[Principal, Depends(get_principal)]
ActivePrincipalDep = Annotated[Principal, Depends(get_active_principal)]


def _resource_visible(db: Session, p: Principal, raw_id: str) -> bool:
    """Is the material reachable by this principal at all (404 before 403)?"""
    try:
        material_id = uuid.UUID(raw_id)
    except ValueError:
        return False
    m = db.get(Material, material_id)
    if m is None:
        return False
    if p.kind == OrganizationKind.supplier:
        return m.organization_id == p.organization_id
    return m.status in (MaterialStatus.available, MaterialStatus.partially_allocated) and (
        m.available_kg > 0
    )


def require_permission(*permissions: str, any_of: bool = False, material_param: str | None = None):
    """Dependency factory. With material_param the 404-before-403 rule applies to that path ID."""

    def dep(request: Request, p: ActivePrincipalDep, db: DbSession) -> Principal:
        ok = any(p.can(x) for x in permissions) if any_of else all(p.can(x) for x in permissions)
        if ok:
            # 404 on ownership precedes body validation (422): dependencies run before the body.
            if material_param and not _resource_visible(
                db, p, str(request.path_params.get(material_param, ""))
            ):
                raise not_found()
            return p
        if material_param and not _resource_visible(
            db, p, str(request.path_params.get(material_param, ""))
        ):
            raise not_found()
        raise AppError(403, "FORBIDDEN")

    return dep


def perm(*permissions: str, **kw):
    return Annotated[Principal, Depends(require_permission(*permissions, **kw))]


def platform_admin(user: CurrentUser, db: DbSession) -> User:
    if db.get(PlatformAdmin, user.id) is None:
        raise AppError(403, "FORBIDDEN")
    return user


PlatformAdminUser = Annotated[User, Depends(platform_admin)]


def client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"
