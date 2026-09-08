from pydantic_settings import BaseSettings
from functools import lru_cache
from typing import Optional


class Settings(BaseSettings):
    # Database individual parameters
    postgres_user: str = "taskuser"
    postgres_password: str = "taskpass"
    postgres_host: str = "localhost"
    postgres_port: str = "5432"
    postgres_db: str = "taskdb"

    # Or use a full DATABASE_URL (takes precedence if provided)
    database_url: Optional[str] = None

    # Application settings
    app_name: str = "Task Management API"
    app_version: str = "1.0.0"

    # External IdP configuration: issuer/audience to validate in the token,
    # and the JWKS endpoint used to fetch the signing keys.
    jwt_issuer: Optional[str] = None
    jwt_audience: Optional[str] = None
    jwt_jwk_url: Optional[str] = None
    jwt_algorithms: str = "RS256"
    jwt_leeway_seconds: int = 0

    # Optional HTTP Basic auth credentials, provided via external configuration
    # (e.g. a Kubernetes Secret). Valid credentials grant the admin role, i.e.
    # both scopes (full access).
    basic_auth_username: Optional[str] = None
    basic_auth_password: Optional[str] = None

    class Config:
        env_file = ".env"

    def get_database_url(self) -> str:
        """Construct database URL from individual parameters or use DATABASE_URL if provided"""
        if self.database_url:
            return self.database_url
        return f"postgresql://{self.postgres_user}:{self.postgres_password}@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"


@lru_cache()
def get_settings():
    return Settings()
