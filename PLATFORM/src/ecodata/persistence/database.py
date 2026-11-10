from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import sessionmaker

from ecodata.domain.health import DatabaseUnavailable
from ecodata.infrastructure.config import Settings


class Database:
    def __init__(self, settings: Settings) -> None:
        self.engine = create_engine(
            settings.database_url.get_secret_value(),
            pool_pre_ping=True,
            pool_timeout=5,
            connect_args={
                "connect_timeout": settings.database_connect_timeout,
                "options": "-c statement_timeout=5000",
            },
        )
        self.sessions = sessionmaker(bind=self.engine, expire_on_commit=False)

    def check(self) -> None:
        try:
            with self.sessions() as session:
                session.execute(text("SELECT 1")).scalar_one()
        except SQLAlchemyError:
            raise DatabaseUnavailable("Database connectivity check failed") from None

    def dispose(self) -> None:
        self.engine.dispose()
