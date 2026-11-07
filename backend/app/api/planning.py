from fastapi import APIRouter, BackgroundTasks, Response
from sqlalchemy import select

from app.api.deps import DbSession, Limiter, SettingsDep, perm
from app.core.errors import AppError, not_found
from app.models.planning import Analysis
from app.schemas.planning import (
    AnalysisAccepted,
    AnalysisOut,
    MatchIn,
    MatchOut,
    MaterialReference,
    OptimizationIn,
    OptimizationOut,
)
from app.services import matching, planning, vision
from app.services.materials import get_owned, parse_uuid_or_404

router = APIRouter(tags=["Analysis and planning"])
Planner = perm("planning.run")
PlanReader = perm("planning.read")
Analyzer = perm("ai.analyze")


def limit(limiter, user, operation):
    limiter.hit(f"{operation}:{user.id}", 6, 600)


@router.post("/ai/match", response_model=MatchOut)
def match(data: MatchIn, user: Planner, db: DbSession, limiter: Limiter):
    limit(limiter, user, "match")
    materials, requirements, organizations = planning.inputs(db, user, [data.material_id])
    return matching.match(materials[0], requirements, organizations, data.limit)


@router.post("/optimization/run", status_code=201, response_model=OptimizationOut)
def optimize(
    data: OptimizationIn,
    user: Planner,
    db: DbSession,
    settings: SettingsDep,
    limiter: Limiter,
):
    limit(limiter, user, "optimize")
    return planning.create_run(db, user, data, settings)


@router.get("/optimization/runs/{id}", response_model=OptimizationOut)
def get_run(id: str, user: PlanReader, db: DbSession):
    return planning.get_run(db, user, id)


@router.post("/ai/analyze", status_code=202, response_model=AnalysisAccepted)
def analyze(
    data: MaterialReference,
    tasks: BackgroundTasks,
    response: Response,
    user: Analyzer,
    db: DbSession,
    settings: SettingsDep,
    limiter: Limiter,
):
    limit(limiter, user, "analyze")
    limiter.hit(f"analyze:org:{user.organization_id}", 30, 86400)
    m = get_owned(db, user, str(data.material_id), lock=True)
    if not m.images:
        raise AppError(409, "PRECONDITION_FAILED", details={"reason": "NO_IMAGES"})
    if m.status == "archived":
        raise AppError(409, "INVALID_TRANSITION")
    job = db.scalar(
        select(Analysis).where(
            Analysis.material_id == m.id,
            Analysis.input_version == m.version,
            Analysis.status.in_(("pending", "running")),
        )
    )
    if job is None:
        job = Analysis(
            material_id=m.id,
            input_version=m.version,
            provider=settings.vision_provider,
            model=settings.vision_model,
            image_snapshot=[dict(key=i.storage_key, mime_type=i.mime_type) for i in m.images],
        )
        db.add(job)
        db.flush()
        tasks.add_task(vision.run_analysis, job.id)
    accepted = dict(analysis_id=str(job.id), status=job.status, input_version=job.input_version)
    db.commit()
    response.headers["Location"] = f"/ai/analyses/{job.id}"
    return accepted


@router.get("/ai/analyses/{id}", response_model=AnalysisOut)
def get_analysis(id: str, user: Analyzer, db: DbSession):
    job = db.get(Analysis, parse_uuid_or_404(id))
    if job is None:
        raise not_found()
    m = get_owned(db, user, str(job.material_id))
    return {
        **{
            k: getattr(job, k)
            for k in (
                "id",
                "material_id",
                "status",
                "input_version",
                "mode",
                "schema_version",
                "provider",
                "model",
                "error_code",
                "confirmed_at",
                "confirmed_by",
                "created_at",
                "updated_at",
            )
        },
        "is_current": job.input_version == m.version,
        "requires_confirmation": True,
        "result": job.validated_result,
    }
