"""Create an admin explicitly from the server console; never via public registration."""

import argparse
import getpass
from datetime import UTC, datetime

from pydantic import TypeAdapter
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.db.session import get_engine
from app.models import Organization, PlatformAdmin, User
from app.models.enums import ActivityType, Role
from app.schemas.types import Email
from app.services import audit


def main():
    parser = argparse.ArgumentParser(description="Создать администратора ARTA")
    parser.add_argument("--email", required=True)
    args = parser.parse_args()
    email = TypeAdapter(Email).validate_python(args.email)
    password = getpass.getpass("Пароль (10–128 символов): ")
    if not 10 <= len(password) <= 128:
        raise SystemExit("Пароль должен содержать 10–128 символов.")
    if password != getpass.getpass("Повторите пароль: "):
        raise SystemExit("Пароли не совпадают.")
    with Session(get_engine()) as db:
        if db.scalar(select(User.id).where(User.email == email)):
            raise SystemExit("Email уже занят. Существующая учётная запись не изменена.")
        org = Organization(
            name="Администрация ARTA", city="Бишкек", activity_type=ActivityType.other
        )
        db.add(org)
        db.flush()
        admin_user = User(
            email=email,
            password_hash=hash_password(password),
            role=Role.admin,
            organization_id=org.id,
            active=True,
            email_confirmed=True,
            email_confirmed_at=datetime.now(UTC),
        )
        db.add(admin_user)
        db.flush()
        # Platform admin is a separate mechanism: no organization membership, no kind.
        db.add(PlatformAdmin(user_id=admin_user.id))
        audit.record(
            db,
            "platform_admin.created",
            target_type="user",
            target_id=admin_user.id,
        )
        db.commit()
    print(f"Администратор {email} создан. Вход: /admin")


if __name__ == "__main__":
    main()
