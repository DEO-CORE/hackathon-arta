from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, Query, Response, UploadFile

from app.api.deps import CatalogUser, DbSession, EnterpriseUser, Limiter, SettingsDep
from app.core.errors import AppError
from app.integrations.storage import ObjectStorage
from app.integrations.storage.factory import get_storage
from app.schemas.material import (
    ImageUploadOut,
    MaterialConfirmIn,
    MaterialCreateIn,
    MaterialImageOut,
    MaterialOut,
    MaterialPatchIn,
    MaterialPublicOut,
    MaterialVersionIn,
    Page,
)
from app.services import images as image_service
from app.services import materials as svc
from app.services.materials import MaterialListQuery

router = APIRouter(prefix="/materials", tags=["materials"])

Storage = Annotated[ObjectStorage, Depends(get_storage)]


@router.get("", response_model=Page[MaterialOut] | Page[MaterialPublicOut])
def list_materials(
    q: Annotated[MaterialListQuery, Query()], user: CatalogUser, db: DbSession
) -> Page:
    return svc.list_materials(db, user, q)


@router.post("", status_code=201, response_model=MaterialOut)
def create_material(
    data: MaterialCreateIn, response: Response, user: EnterpriseUser, db: DbSession
) -> MaterialOut:
    m = svc.create_material(db, user, data)
    response.headers["Location"] = f"/materials/{m.id}"
    return svc.material_out(m)


@router.get("/{material_id}", response_model=MaterialOut | MaterialPublicOut)
def get_material(material_id: str, user: CatalogUser, db: DbSession):
    return svc.get_for_user(db, user, material_id)


@router.patch("/{material_id}", response_model=MaterialOut)
def patch_material(
    material_id: str, data: MaterialPatchIn, user: EnterpriseUser, db: DbSession
) -> MaterialOut:
    return svc.material_out(svc.patch_material(db, user, material_id, data))


@router.post("/{material_id}/confirm", response_model=MaterialOut)
def confirm_material(
    material_id: str, data: MaterialConfirmIn, user: EnterpriseUser, db: DbSession
) -> MaterialOut:
    m = svc.confirm_material(db, user, material_id, data.version, data.analysis_id)
    return svc.material_out(m)


def _lifecycle_limit(limiter: Limiter, settings: SettingsDep, user_id, action: str) -> None:
    limiter.hit(
        f"{action}:{user_id}",
        settings.rate_limit_lifecycle_per_user,
        settings.rate_limit_window_seconds,
    )


@router.post("/{material_id}/publish", response_model=MaterialOut)
def publish_material(
    material_id: str,
    data: MaterialVersionIn,
    user: EnterpriseUser,
    db: DbSession,
    limiter: Limiter,
    settings: SettingsDep,
) -> MaterialOut:
    _lifecycle_limit(limiter, settings, user.id, "publish")
    return svc.material_out(svc.publish_material(db, user, material_id, data.version))


@router.post("/{material_id}/archive", response_model=MaterialOut)
def archive_material(
    material_id: str,
    data: MaterialVersionIn,
    user: EnterpriseUser,
    db: DbSession,
    limiter: Limiter,
    settings: SettingsDep,
) -> MaterialOut:
    _lifecycle_limit(limiter, settings, user.id, "archive")
    return svc.material_out(svc.archive_material(db, user, material_id, data.version))


@router.post("/{material_id}/images", status_code=201, response_model=ImageUploadOut)
def upload_image(
    material_id: str,
    user: EnterpriseUser,
    db: DbSession,
    limiter: Limiter,
    settings: SettingsDep,
    storage: Storage,
    file: Annotated[UploadFile, File()],
    sort_order: Annotated[int | None, Form(ge=0)] = None,
) -> ImageUploadOut:
    limiter.hit(
        f"upload:{user.id}", settings.rate_limit_upload_per_user, settings.rate_limit_window_seconds
    )
    svc.precheck_image_upload(db, user, material_id)
    raw = file.file.read(image_service.MAX_BYTES + 1)
    if len(raw) > image_service.MAX_BYTES:
        raise AppError(
            422,
            "UNSUPPORTED_IMAGE",
            details={"reason": "bytes", "max_bytes": image_service.MAX_BYTES},
        )
    image, version = svc.add_image(db, user, material_id, raw, sort_order, storage)
    return ImageUploadOut(image=MaterialImageOut.model_validate(image), material_version=version)
