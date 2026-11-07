from functools import lru_cache

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Environment-driven settings. Secrets have no defaults: startup fails without them."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore", case_sensitive=False)

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
