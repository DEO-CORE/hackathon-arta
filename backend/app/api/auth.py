from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, Request

from app.api.deps import DbSession, Limiter, PrincipalDep, SettingsDep, client_ip
from app.integrations.mail import Mailer, build_mailer
from app.schemas.auth import (
    EmailCodeSendIn,
    EmailCodeSendOut,
    EmailCodeVerifyIn,
    EmailVerifiedOut,
    LoginIn,
    MembershipOut,
    MeOut,
    RegisterIn,
    TokenOut,
    UserOut,
    UserWithOrganizationOut,
)
from app.schemas.organization import organization_out
from app.services import auth as auth_service
from app.services import email_confirmation as email_service

router = APIRouter(prefix="/auth", tags=["auth"])


def get_mailer(settings: SettingsDep) -> Mailer | None:
    return build_mailer(settings)


MailerDep = Annotated[Mailer | None, Depends(get_mailer)]


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


@router.get("/me", response_model=MeOut)
def me(principal: PrincipalDep) -> MeOut:
    return MeOut(
        user=UserOut.model_validate(principal.user),
        organization=organization_out(principal.organization),
        organization_kind=principal.kind,
        membership=MembershipOut(
            organization_id=principal.organization_id,
            role=principal.membership.role,
            status=principal.membership.status,
        ),
        default_organization_id=principal.user.default_organization_id,
        permissions=sorted(principal.permissions),
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


@router.post("/email-code/send", status_code=202, response_model=EmailCodeSendOut)
def email_code_send(
    data: EmailCodeSendIn,
    request: Request,
    background: BackgroundTasks,
    db: DbSession,
    settings: SettingsDep,
    limiter: Limiter,
    mailer: MailerDep,
) -> EmailCodeSendOut:
    email = data.email.strip().lower()
    # Limits apply to every email, existing or not, so 429 reveals nothing about accounts.
    limiter.hit(f"email-send-cooldown:{email}", 1, settings.email_resend_cooldown_seconds)
    limiter.hit(f"email-send-hour:{email}", settings.email_send_per_hour_email, 3600)
    limiter.hit(f"email-send-ip:{client_ip(request)}", settings.email_send_per_hour_ip, 3600)
    # 503 is configuration-level and identical for every email.
    email_service.check_delivery_available(settings, mailer)
    code = email_service.request_code(db, settings, email)
    if code is not None and mailer is not None:
        background.add_task(email_service.deliver, mailer, email, code)
    return EmailCodeSendOut(resend_after_seconds=settings.email_resend_cooldown_seconds)


@router.post("/email-code/verify", response_model=EmailVerifiedOut)
def email_code_verify(
    data: EmailCodeVerifyIn,
    request: Request,
    db: DbSession,
    settings: SettingsDep,
    limiter: Limiter,
) -> EmailVerifiedOut:
    email = data.email.strip().lower()
    window = settings.rate_limit_window_seconds
    limiter.hit(f"verify-ip:{client_ip(request)}", settings.rate_limit_login_per_ip, window)
    limiter.hit(f"verify-email:{email}", settings.rate_limit_login_per_email, window)
    return EmailVerifiedOut(user=email_service.verify_code(db, settings, email, data.code))
