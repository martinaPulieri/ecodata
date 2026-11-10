import pytest
from pydantic import ValidationError

from ecodata.infrastructure.config import Settings


@pytest.mark.parametrize("url", ["sqlite:///data.db", "postgresql://localhost/db", "garbage"])
def test_rejects_non_psycopg_postgresql_urls(url):
    with pytest.raises(ValidationError):
        Settings(_env_file=None, database_url=url)


def test_reads_environment_without_exposing_database_password(monkeypatch):
    monkeypatch.setenv(
        "ECODATA_DATABASE_URL", "postgresql+psycopg://researcher:private@localhost/ecodata"
    )
    config = Settings(_env_file=None)
    assert "researcher:private" in config.database_url.get_secret_value()
    assert "private" not in repr(config)


def test_rejects_unbounded_connection_timeout():
    with pytest.raises(ValidationError):
        Settings(_env_file=None, database_connect_timeout=0)
