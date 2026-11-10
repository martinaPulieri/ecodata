from fastapi.testclient import TestClient
from pydantic import SecretStr

from ecodata.api.dependencies import get_readiness_probe
from ecodata.domain.health import DatabaseUnavailable
from ecodata.infrastructure.config import Settings
from ecodata.main import create_app


def settings() -> Settings:
    # A refused local port is deterministic; no developer database is contacted.
    return Settings(
        _env_file=None,
        database_url=SecretStr("postgresql+psycopg://test:secret@127.0.0.1:1/test"),
        database_connect_timeout=1,
    )


def test_liveness_does_not_require_database():
    with TestClient(create_app(settings())) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_readiness_reports_success_after_probe():
    class AvailableDatabase:
        def check(self) -> None:
            pass

    app = create_app(settings())
    app.dependency_overrides[get_readiness_probe] = AvailableDatabase
    with TestClient(app) as client:
        response = client.get("/health/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "ok"}


def test_readiness_reports_unavailable_without_exposing_secrets():
    class UnavailableDatabase:
        def check(self) -> None:
            raise DatabaseUnavailable("private database diagnostics")

    app = create_app(settings())
    app.dependency_overrides[get_readiness_probe] = UnavailableDatabase
    with TestClient(app) as client:
        response = client.get("/health/ready")
    assert response.status_code == 503
    assert response.json() == {"status": "unavailable", "database": "unavailable"}
    assert "private" not in response.text


def test_real_connection_refusal_returns_503_and_keeps_app_alive():
    with TestClient(create_app(settings())) as client:
        response = client.get("/health/ready")
        assert client.get("/health").status_code == 200
    assert response.status_code == 503
    assert response.json()["database"] == "unavailable"
    assert "secret" not in response.text


def test_app_instances_have_independent_database_resources():
    first = create_app(settings())
    second = create_app(settings())
    with TestClient(first), TestClient(second):
        assert first.state.database is not second.state.database
        assert first.state.database.engine is not second.state.database.engine
