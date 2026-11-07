"""Mail adapter. Credentials come only from environment settings (docs/api.md 23)."""

import logging
import smtplib
from email.message import EmailMessage
from typing import Protocol

from app.core.config import Settings

logger = logging.getLogger("arta.mail")


class Mailer(Protocol):
    def send_code(self, to_email: str, code: str) -> None: ...


class SmtpMailer:
    def __init__(self, settings: Settings) -> None:
        self._host = settings.smtp_host or ""
        self._port = settings.smtp_port
        self._user = settings.smtp_username
        self._password = (
            settings.smtp_password.get_secret_value() if settings.smtp_password else None
        )
        self._from = settings.smtp_from or ""
        self._starttls = settings.smtp_starttls

    def send_code(self, to_email: str, code: str) -> None:
        msg = EmailMessage()
        msg["From"] = self._from
        msg["To"] = to_email
        msg["Subject"] = "ARTA: код подтверждения email"
        msg.set_content(
            f"Ваш код подтверждения: {code}\nКод действует 10 минут. "
            "Если вы не регистрировались в ARTA, проигнорируйте письмо."
        )
        with smtplib.SMTP(self._host, self._port, timeout=10) as smtp:
            if self._starttls:
                smtp.starttls()
            if self._user and self._password:
                smtp.login(self._user, self._password)
            smtp.send_message(msg)


def build_mailer(settings: Settings) -> Mailer | None:
    """None means delivery is not configured; the caller must answer 503, never fake success."""
    if settings.demo_mode or settings.mail_provider != "smtp":
        return None
    return SmtpMailer(settings)
