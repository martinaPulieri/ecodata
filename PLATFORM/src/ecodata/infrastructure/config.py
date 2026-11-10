from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import make_url
from sqlalchemy.exc import ArgumentError


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="ECODATA_", env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    database_url: SecretStr = SecretStr(
        "postgresql+psycopg://ecodata:ecodata@localhost:5432/ecodata"
    )
    database_connect_timeout: int = Field(default=3, ge=1, le=30)

    @field_validator("database_url")
    @classmethod
    def require_postgresql_psycopg(cls, value: SecretStr) -> SecretStr:
        try:
            url = make_url(value.get_secret_value())
        except ArgumentError:
            raise ValueError("A valid PostgreSQL SQLAlchemy URL is required") from None
        if url.drivername != "postgresql+psycopg":
            raise ValueError("Use the postgresql+psycopg driver")
        return value
