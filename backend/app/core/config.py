from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Environment-driven settings. Secrets have no defaults: startup fails without them."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore", case_sensitive=False)

    app_env: Literal["development", "production", "test"] = "development"
    demo_mode: bool = False
    vision_provider: Literal["disabled", "mock", "http_json"] = "disabled"
    vision_model: str | None = None
    vision_endpoint: str | None = None
    vision_api_key: SecretStr | None = None
    vision_timeout_seconds: int = Field(20, ge=1, le=20)
    optimization_timeout_seconds: int = Field(5, ge=1, le=30)

    # Email confirmation (docs/api.md 23). No defaults for secrets: without them the send
    # endpoint answers 503 EMAIL_DELIVERY_UNAVAILABLE instead of pretending to send.
    email_code_hmac_key: SecretStr | None = None
    mail_provider: Literal["disabled", "smtp"] = "disabled"
    smtp_host: str | None = None
    smtp_port: int = Field(587, ge=1, le=65535)
    smtp_username: str | None = None
    smtp_password: SecretStr | None = None
    smtp_from: str | None = None
    smtp_starttls: bool = True
    email_code_ttl_seconds: int = Field(600, ge=30)
    email_code_max_attempts: int = Field(5, ge=1)
    email_code_lock_seconds: int = Field(900, ge=1)
    email_resend_cooldown_seconds: int = Field(60, ge=1)
    email_send_per_hour_email: int = Field(5, ge=1)
    email_send_per_hour_ip: int = Field(20, ge=1)

    database_url: str
    jwt_secret: SecretStr
    cors_origins: str = ""
    storage_local_dir: str = "var/storage"
    access_token_minutes: int = Field(default=60, ge=1)
    jwt_algorithm: str = "HS256"

    rate_limit_window_seconds: int = Field(default=60, ge=1)
    rate_limit_login_per_email: int = Field(default=10, ge=1)
    rate_limit_login_per_ip: int = Field(default=30, ge=1)
    rate_limit_register_per_ip: int = Field(default=10, ge=1)
    rate_limit_upload_per_user: int = Field(default=30, ge=1)
    rate_limit_lifecycle_per_user: int = Field(default=30, ge=1)

    @model_validator(mode="after")
    def validate_demo_isolation(self):
        # The demo code 7777 must never coexist with production signs (A23-13).
        if self.demo_mode and (self.app_env == "production" or self.mail_provider != "disabled"):
            raise ValueError(
                "DEMO_MODE=true is incompatible with production or a real mail provider"
            )
        if self.mail_provider == "smtp" and not (self.smtp_host and self.smtp_from):
            raise ValueError("MAIL_PROVIDER=smtp requires SMTP_HOST and SMTP_FROM")
        if self.email_code_hmac_key and len(self.email_code_hmac_key.get_secret_value()) < 32:
            raise ValueError("EMAIL_CODE_HMAC_KEY must be at least 32 characters")
        return self

    @model_validator(mode="after")
    def validate_vision(self):
        if self.vision_provider == "mock" and not self.demo_mode:
            raise ValueError("VISION_PROVIDER=mock requires DEMO_MODE=true")
        if self.vision_provider == "http_json":
            if not self.vision_endpoint or not self.vision_model or not self.vision_api_key:
                raise ValueError("HTTP vision requires endpoint, model and API key")
            if not self.vision_endpoint.startswith("https://"):
                raise ValueError("VISION_ENDPOINT must use HTTPS")
        if self.app_env == "production" and (self.vision_provider != "http_json" or self.demo_mode):
            raise ValueError(
                "Production requires a configured real vision provider without demo mode"
            )
        return self

    @field_validator("jwt_secret")
    @classmethod
    def _secret_strength(cls, v: SecretStr) -> SecretStr:
        if len(v.get_secret_value()) < 32:
            raise ValueError("JWT_SECRET must be at least 32 characters")
        return v

    @field_validator("database_url")
    @classmethod
    def _driver(cls, v: str) -> str:
        # Accept plain postgresql:// and pin the psycopg3 driver.
        if v.startswith("postgresql://"):
            return "postgresql+psycopg://" + v[len("postgresql://") :]
        return v

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
