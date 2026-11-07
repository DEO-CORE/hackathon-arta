from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Request, Response
from pydantic import Field

from app.api.deps import (
    CurrentUser,
    DbSession,
    Limiter,
    SettingsDep,
    check_browser_origin,
    client_ip,
)
from app.models import Organization
from app.schemas.auth import (
    LoginIn,
    RegisterIn,
    TokenOut,
    UserOut,
    UserWithOrganizationOut,
)
from app.schemas.organization import organization_out
from app.schemas.types import Email, StrictIn
from app.services import auth as auth_service
from app.services import passwords

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
        user=UserOut.model_validate(user), organization=organization_out(org) if org else None
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


@router.get("/me", response_model=UserWithOrganizationOut)
def me(user: CurrentUser, db: DbSession):
    org = db.get(Organization, user.organization_id) if user.organization_id else None
    return UserWithOrganizationOut(
        user=UserOut.model_validate(user), organization=organization_out(org) if org else None
    )


@router.post("/session", response_model=UserOut)
def browser_login(
    data: LoginIn,
    request: Request,
    response: Response,
    db: DbSession,
    settings: SettingsDep,
    limiter: Limiter,
):
    check_browser_origin(request, settings)
    result = login(data, request, db, settings, limiter)
    response.set_cookie(
        "arta_session",
        result.access_token,
        httponly=True,
        secure=settings.app_env == "production",
        samesite="lax",
        max_age=result.expires_in,
        path="/",
    )
    response.headers["Cache-Control"] = "no-store"
    return result.user


@router.delete("/session", status_code=204)
def browser_logout(request: Request, response: Response, settings: SettingsDep):
    check_browser_origin(request, settings)
    response.delete_cookie("arta_session", path="/")


class ForgotPassword(StrictIn):
    email: Email


class ResetPassword(StrictIn):
    token: Annotated[str, Field(min_length=32, max_length=128)]
    password: Annotated[str, Field(min_length=10, max_length=128)]


@router.post("/forgot-password", status_code=202)
def forgot_password(
    data: ForgotPassword,
    tasks: BackgroundTasks,
    request: Request,
    db: DbSession,
    settings: SettingsDep,
    limiter: Limiter,
):
    limiter.hit(f"reset-ip:{client_ip(request)}", 10, 600)
    limiter.hit(f"reset-email:{data.email}", 3, 600)
    pending = passwords.prepare_reset(db, data.email, settings)
    if pending:
        tasks.add_task(passwords.send_reset, *pending, settings)
    return {
        "message": "Если аккаунт существует, на указанный email придёт ссылка для смены пароля."
    }


@router.post("/reset-password")
def reset_password(
    data: ResetPassword, request: Request, db: DbSession, limiter: Limiter, response: Response
):
    limiter.hit(f"reset-confirm:{client_ip(request)}", 10, 600)
    passwords.reset_password(db, data.token, data.password)
    response.delete_cookie("arta_session", path="/")
    return {"message": "Пароль изменён. Войдите с новым паролем."}
