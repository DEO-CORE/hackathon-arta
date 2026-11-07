import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import auth, health, materials, organizations
from app.core.config import get_settings
from app.core.errors import register_exception_handlers
from app.core.middleware import RequestContextMiddleware
from app.core.ratelimit import RateLimiter


def create_app() -> FastAPI:
    settings = get_settings()  # fails fast when DATABASE_URL / JWT_SECRET are missing
    logging.basicConfig(level=logging.INFO)
    app = FastAPI(title="ARTA API", version="0.1.0")
    app.state.limiter = RateLimiter()
    register_exception_handlers(app)
    if settings.cors_origin_list:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origin_list,
            allow_methods=["GET", "POST", "PATCH", "DELETE"],
            allow_headers=["Authorization", "Content-Type", "Idempotency-Key"],
            expose_headers=["X-Request-ID", "Retry-After", "Location", "Idempotent-Replay"],
        )
    app.add_middleware(RequestContextMiddleware)
    for r in (health.router, auth.router, organizations.router, materials.router):
        app.include_router(r)
    return app


app = create_app()
