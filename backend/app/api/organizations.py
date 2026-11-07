from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.core.errors import AppError, not_found
from app.models import Organization
from app.models.enums import ActivityType, Role
from app.schemas.organization import OrganizationOut, OrganizationPatchIn, organization_out

router = APIRouter(prefix="/organizations", tags=["organizations"])


@router.get("/me", response_model=OrganizationOut)
def get_my_organization(user: CurrentUser, db: DbSession) -> OrganizationOut:
    if user.organization_id is None:
        raise not_found()
    org = db.get(Organization, user.organization_id)
    if org is None:
        raise not_found()
    return organization_out(org)


@router.patch("/me", response_model=OrganizationOut)
def patch_my_organization(
    data: OrganizationPatchIn, user: CurrentUser, db: DbSession
) -> OrganizationOut:
    if user.organization_id is None:
        raise not_found()
    org = db.get(Organization, user.organization_id)
    if org is None:
        raise not_found()
    sent = data.model_fields_set
    if "activity_type" in sent and data.activity_type == ActivityType.recycler:
        if user.role != Role.buyer:
            raise AppError(
                422,
                "VALIDATION_ERROR",
                details={
                    "errors": [
                        {
                            "field": "activity_type",
                            "code": "invalid_value",
                            "message": "Переработчиком может быть только покупатель.",
                        }
                    ]
                },
            )
    for field in ("name", "city", "activity_type"):
        if field in sent:
            setattr(org, field, getattr(data, field))
    if "contacts" in sent:
        # Replaces the whole block; omitted inner fields become null (api.md 17.4).
        org.contact_name = data.contacts.contact_name
        org.contact_phone = data.contacts.contact_phone
        org.contact_email = data.contacts.contact_email
    db.commit()
    return organization_out(org)
