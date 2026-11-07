from fastapi import APIRouter, Request

from app.api.deps import DbSession, Limiter, SettingsDep, client_ip
from app.schemas.auth import (
    LoginIn,
    RegisterIn,
    TokenOut,
    UserOut,
    UserWithOrganizationOut,
)
from app.schemas.organization import organization_out
from app.services import auth as auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", status_code=201, response_model=UserWithOrganizationOut)
def register(
    data: RegisterIn, request: Request, db: DbSession, settings: SettingsDep, limiter: Limiter
) -> UserWithOrganizationOut:
    limiter.hit(
        f"register:{client_ip(request)}",
        settings.rate_limit_register_per_ip,
        settings.rate_limit_window_seconds,
    )
    user, org = auth_service.register(db, data)
    return UserWithOrganizationOut(
        user=UserOut.model_validate(user), organization=organization_out(org)
    )


@router.post("/login", response_model=TokenOut)
def login(
    data: LoginIn, request: Request, db: DbSession, settings: SettingsDep, limiter: Limiter
) -> TokenOut:
    ip = client_ip(request)
    window = settings.rate_limit_window_seconds
    email = data.email.strip().lower()
    limiter.hit(f"login-ip:{ip}", settings.rate_limit_login_per_ip, window)
    limiter.hit(f"login-pair:{ip}:{email}", settings.rate_limit_login_per_email, window)
    return auth_service.login(db, data, settings)
