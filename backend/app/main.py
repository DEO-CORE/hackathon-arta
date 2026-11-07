import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import update
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.api import (
    admin,
    analytics,
    auth,
    commerce,
    health,
    materials,
    organizations,
    planning,
    public,
)
from app.core.config import get_settings
from app.core.errors import register_exception_handlers
from app.core.middleware import RequestContextMiddleware
from app.core.ratelimit import RateLimiter
from app.db.session import get_engine
from app.models.planning import Analysis


def recover_interrupted_jobs():
    with Session(get_engine()) as db:
        db.execute(
            update(Analysis)
            .where(Analysis.status.in_(("pending", "running")))
            .values(status="interrupted", error_code="INTERRUPTED")
        )
        db.commit()


@asynccontextmanager
async def lifespan(app):
    await run_in_threadpool(recover_interrupted_jobs)
    logging.getLogger("arta").info("Vision provider: %s", get_settings().vision_provider)
    yield


def create_app() -> FastAPI:
    settings = get_settings()  # fails fast when DATABASE_URL / JWT_SECRET are missing
    logging.basicConfig(level=logging.INFO)
    app = FastAPI(title="ARTA API", version="0.2.0", lifespan=lifespan)
    app.state.limiter = RateLimiter()
    register_exception_handlers(app)
    if settings.cors_origin_list:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origin_list,
            allow_credentials=True,
            allow_methods=["GET", "POST", "PATCH", "DELETE"],
            allow_headers=["Authorization", "Content-Type", "Idempotency-Key"],
            expose_headers=["X-Request-ID", "Retry-After", "Location", "Idempotent-Replay"],
        )
    app.add_middleware(RequestContextMiddleware)
    for r in (
        admin.router,
        public.router,
        health.router,
        auth.router,
        organizations.router,
        materials.router,
        commerce.router,
        planning.router,
        analytics.router,
    ):
        app.include_router(r)
    return app


app = create_app()
