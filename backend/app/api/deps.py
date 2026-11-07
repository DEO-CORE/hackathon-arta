from collections.abc import Callable
from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.errors import AppError
from app.core.ratelimit import RateLimiter
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models import User
from app.models.enums import Role

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


def require_roles(*roles: Role) -> Callable[[User], User]:
    def dep(user: CurrentUser) -> User:
        if user.role not in roles:
            raise AppError(403, "FORBIDDEN")
        return user

    return dep


EnterpriseUser = Annotated[User, Depends(require_roles(Role.enterprise))]
CatalogUser = Annotated[User, Depends(require_roles(Role.enterprise, Role.buyer))]


def client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"
