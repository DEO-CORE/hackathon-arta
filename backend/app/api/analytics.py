from fastapi import APIRouter

from app.api.deps import CatalogUser, DbSession, SettingsDep
from app.schemas.planning import BuyerSummary, EnterpriseSummary
from app.services.analytics import summary

router = APIRouter(tags=["Analytics"])


@router.get("/analytics/summary", response_model=EnterpriseSummary | BuyerSummary)
def get_summary(user: CatalogUser, db: DbSession, settings: SettingsDep):
    return summary(db, user, settings)
