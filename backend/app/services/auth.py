from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.errors import AppError
from app.core.security import create_access_token, hash_password, verify_password
from app.models import Organization, User
from app.models.enums import Role
from app.schemas.auth import LoginIn, RegisterIn, TokenOut, UserOut


def register(db: Session, data: RegisterIn) -> tuple[User, Organization]:
    # Role comes from the RegisterRole enum, so admin cannot be self-assigned, and the
    # organization is always created fresh (no joining an existing one by ID).
    if db.scalar(select(User.id).where(User.email == data.email)) is not None:
        raise AppError(409, "EMAIL_ALREADY_REGISTERED")
    contacts = data.organization.contacts
    org = Organization(
        name=data.organization.name,
        city=data.organization.city,
        activity_type=data.organization.activity_type,
        contact_name=contacts.contact_name if contacts else None,
        contact_phone=contacts.contact_phone if contacts else None,
        contact_email=contacts.contact_email if contacts else None,
    )
    if org.activity_type.value == "recycler" and data.role.value != "buyer":
        raise AppError(
            422,
            "VALIDATION_ERROR",
            details={
                "errors": [
                    {
                        "field": "organization.activity_type",
                        "code": "invalid_value",
                        "message": "Переработчик регистрируется с ролью покупателя.",
                    }
                ]
            },
        )
    db.add(org)
    db.flush()
    user = User(
        email=data.email,
        password_hash=hash_password(data.password),
        role=Role(data.role.value),
        organization_id=org.id,
        active=True,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise AppError(409, "EMAIL_ALREADY_REGISTERED") from None
    return user, org


def login(db: Session, data: LoginIn, settings: Settings) -> TokenOut:
    email = data.email.strip().lower()
    user = db.scalar(select(User).where(User.email == email))
    # Hash is checked even for unknown emails to equalise timing (api.md 18.9).
    valid = verify_password(user.password_hash if user else None, data.password)
    if user is None or not valid:
        raise AppError(401, "INVALID_CREDENTIALS")
    if not user.active:
        raise AppError(403, "ACCOUNT_DISABLED")
    token, expires_in = create_access_token(user.id, settings)
    return TokenOut(access_token=token, expires_in=expires_in, user=UserOut.model_validate(user))
