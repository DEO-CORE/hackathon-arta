"""Public landing data excludes contacts, private balances, drafts and AI suggestions."""

from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from typing import Annotated
from uuid import UUID

import jwt
from fastapi import APIRouter, Query
from fastapi.responses import FileResponse
from sqlalchemy import func, select

from app.api.deps import CurrentUser, DbSession, SettingsDep
from app.core.errors import not_found
from app.models import Material, MaterialImage, Organization, User
from app.models.commerce import ImpactRecord
from app.models.enums import Role
from app.schemas.material import MaterialPublicOut, Page
from app.services import materials
from app.services.materials import BUYER_VISIBLE, MaterialListQuery, parse_uuid_or_404

router = APIRouter(tags=["Landing"])


def published(db, raw_id):
    row = db.scalar(
        select(Material).where(
            Material.id == parse_uuid_or_404(raw_id),
            Material.status.in_(BUYER_VISIBLE),
            Material.available_kg > 0,
        )
    )
    if row is None:
        raise not_found()
    return row


@router.get("/public/materials", response_model=Page[MaterialPublicOut])
def catalog(q: Annotated[MaterialListQuery, Query()], db: DbSession):
    return materials.list_materials(db, SimpleNamespace(role=Role.buyer), q)


@router.get("/public/materials/{id}", response_model=MaterialPublicOut)
def detail(id: str, db: DbSession):
    m = published(db, id)
    return materials.public_out(m, db.get(Organization, m.organization_id).name)


@router.get("/public/statistics")
def statistics(db: DbSession):
    totals = db.execute(
        select(
            func.coalesce(func.sum(Material.total_kg), 0),
            func.coalesce(func.sum(Material.available_kg), 0),
        ).where(Material.status.in_(BUYER_VISIBLE))
    ).one()
    reused = db.scalar(select(func.coalesce(func.sum(ImpactRecord.quantity_kg), 0)))
    return {
        "confirmed_reuse_kg": f"{reused:.3f}",
        "registered_kg": f"{totals[0]:.3f}",
        "available_kg": f"{totals[1]:.3f}",
        "generated_at": datetime.now(UTC),
        "label": "confirmed",
    }


@router.get("/public/material-cities")
def cities(db: DbSession):
    return list(
        db.scalars(
            select(Material.city)
            .where(
                Material.status.in_(BUYER_VISIBLE),
                Material.available_kg > 0,
                Material.city.is_not(None),
            )
            .distinct()
            .order_by(Material.city)
        )
    )


def image_url(db, m, image_id, settings, owner=None):
    img = db.get(MaterialImage, parse_uuid_or_404(image_id))
    if img is None or img.material_id != m.id:
        raise not_found()
    expires = datetime.now(UTC) + timedelta(minutes=5)
    token = jwt.encode(
        {
            "purpose": "image",
            "image": str(img.id),
            "owner": str(owner) if owner else None,
            "exp": expires,
        },
        settings.jwt_secret.get_secret_value(),
        algorithm="HS256",
    )
    return {"url": f"/media/{img.id}?token={token}", "expires_at": expires}


@router.get("/public/materials/{id}/images/{image_id}/url")
def public_image_url(id: str, image_id: str, db: DbSession, settings: SettingsDep):
    return image_url(db, published(db, id), image_id, settings)


@router.get("/materials/{id}/images/{image_id}/url")
def private_image_url(
    id: str, image_id: str, user: CurrentUser, db: DbSession, settings: SettingsDep
):
    if user.role == Role.enterprise:
        m = materials.get_owned(db, user, id)
        return image_url(db, m, image_id, settings, user.id)
    return image_url(db, published(db, id), image_id, settings)


@router.get("/media/{id}", include_in_schema=False)
def image_content(id: str, token: str, db: DbSession, settings: SettingsDep):
    try:
        claims = jwt.decode(
            token,
            settings.jwt_secret.get_secret_value(),
            algorithms=["HS256"],
            options={"require": ["exp", "purpose", "image"]},
        )
        if claims["purpose"] != "image" or claims["image"] != id:
            raise ValueError()
        image = db.get(MaterialImage, UUID(id))
        if image is None:
            raise ValueError()
        material = db.get(Material, image.material_id)
        if claims.get("owner"):
            user = db.get(User, UUID(claims["owner"]))
            if not user or not user.active or user.organization_id != material.organization_id:
                raise ValueError()
        elif material.status not in BUYER_VISIBLE or material.available_kg <= 0:
            raise ValueError()
        root = Path(settings.storage_local_dir).resolve()
        path = (root / image.storage_key).resolve()
        if root not in path.parents or not path.is_file():
            raise ValueError()
    except (jwt.PyJWTError, ValueError, KeyError):
        raise not_found() from None
    return FileResponse(
        path,
        media_type=image.mime_type,
        headers={"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff"},
    )
