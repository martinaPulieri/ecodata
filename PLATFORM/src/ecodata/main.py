from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from ecodata.api.health import router as health_router
from ecodata.infrastructure.config import Settings
from ecodata.persistence.database import Database


def create_app(settings: Settings | None = None) -> FastAPI:
    config = settings if settings is not None else Settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        database = Database(config)
        app.state.database = database
        try:
            yield
        finally:
            database.dispose()

    app = FastAPI(
        title="Ecological Data Integration Platform", version="0.1.0", lifespan=lifespan
    )
    app.include_router(health_router)
    return app
