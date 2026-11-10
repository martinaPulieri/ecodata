"""Opt-in tests against a dedicated PostgreSQL database, never SQLite."""
import os
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import text

from ecodata.infrastructure.config import Settings
from ecodata.main import create_app
from ecodata.persistence.database import Database

pytestmark = pytest.mark.integration


@pytest.fixture
def postgres_settings(monkeypatch):
    url = os.environ.get("ECODATA_TEST_DATABASE_URL")
    if not url:
        pytest.skip("Set ECODATA_TEST_DATABASE_URL to a dedicated PostgreSQL database")
    monkeypatch.setenv("ECODATA_DATABASE_URL", url)
    return Settings(_env_file=None, database_url=url)


def test_postgresql_connection_and_http_readiness(postgres_settings):
    database = Database(postgres_settings)
    try:
        with database.sessions() as session:
            assert session.execute(text("SELECT current_database()")).scalar_one()
        database.check()
    finally:
        database.dispose()
    with TestClient(create_app(postgres_settings)) as client:
        response = client.get("/health/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "ok"}


def test_migrations_reach_head_and_are_idempotent(postgres_settings):
    config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
    command.upgrade(config, "head")
    command.upgrade(config, "head")
    database = Database(postgres_settings)
    try:
        with database.sessions() as session:
            assert session.execute(text("SELECT version_num FROM alembic_version")).scalar_one() == "0001_baseline"
        command.check(config)
    finally:
        database.dispose()
