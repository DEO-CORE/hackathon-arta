import hashlib
import logging
import secrets
import smtplib
import ssl
from datetime import timedelta
from email.message import EmailMessage

from sqlalchemy import select

from app.core.errors import AppError
from app.core.security import hash_password
from app.models import User
from app.models.common import utcnow
from app.models.password_reset import PasswordReset


def digest(token):
    return hashlib.sha256(token.encode()).hexdigest()


def prepare_reset(db, email, settings):
    if not settings.smtp_host or not settings.smtp_from:
        raise AppError(
            503, "MAIL_UNAVAILABLE", "Отправка писем пока не настроена. Попробуйте позже."
        )
    user = db.scalar(select(User).where(User.email == email, User.active.is_(True)))
    if user is None:
        return None
    token = secrets.token_urlsafe(32)
    db.add(
        PasswordReset(
            user_id=user.id,
            token_hash=digest(token),
            token_version=user.token_version,
            expires_at=utcnow() + timedelta(minutes=settings.reset_token_minutes),
        )
    )
    db.commit()
    return user.email, token


def send_reset(email, token, settings):
    # Fragment is not sent in HTTP requests, server access logs or Referer headers.
    link = settings.landing_url.rstrip("/") + "/reset-password#token=" + token
    msg = EmailMessage()
    msg["Subject"] = "ARTA — восстановление пароля"
    msg["From"], msg["To"] = settings.smtp_from, email
    msg.set_content(
        f"Для смены пароля откройте ссылку:\n{link}\n\n"
        f"Срок действия: {settings.reset_token_minutes} минут. "
        "Если вы не запрашивали смену, проигнорируйте письмо."
    )
    try:
        factory = smtplib.SMTP_SSL if settings.smtp_security == "ssl" else smtplib.SMTP
        kwargs = (
            {"context": ssl.create_default_context()} if settings.smtp_security == "ssl" else {}
        )
        with factory(settings.smtp_host, settings.smtp_port, timeout=15, **kwargs) as smtp:
            if settings.smtp_security == "starttls":
                smtp.starttls(context=ssl.create_default_context())
            if settings.smtp_username:
                smtp.login(
                    settings.smtp_username,
                    settings.smtp_password.get_secret_value() if settings.smtp_password else "",
                )
            smtp.send_message(msg)
    except (OSError, smtplib.SMTPException):
        logging.getLogger("arta.mail").error(
            "Password reset delivery failed; check SMTP configuration"
        )


def reset_password(db, token, password):
    record = db.scalar(select(PasswordReset).where(PasswordReset.token_hash == digest(token)))
    if record is None:
        raise AppError(400, "RESET_TOKEN_INVALID", "Ссылка недействительна или устарела.")
    user = db.scalar(select(User).where(User.id == record.user_id).with_for_update())
    db.refresh(record)
    if (
        record.used_at
        or record.expires_at <= utcnow()
        or record.token_version != user.token_version
        or not user.active
    ):
        raise AppError(400, "RESET_TOKEN_INVALID", "Ссылка недействительна или устарела.")
    user.password_hash = hash_password(password)
    user.token_version += 1
    record.used_at = utcnow()
    db.commit()
