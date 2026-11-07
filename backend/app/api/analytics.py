from fastapi import APIRouter

from app.api.deps import DbSession, SettingsDep, perm
from app.schemas.planning import BuyerSummary, EnterpriseSummary
from app.services.analytics import summary

router = APIRouter(tags=["Analytics"])

AnalyticsReader = perm("analytics.read")


@router.get("/analytics/summary", response_model=EnterpriseSummary | BuyerSummary)
def get_summary(user: AnalyticsReader, db: DbSession, settings: SettingsDep):
    return summary(db, user, settings)
