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
