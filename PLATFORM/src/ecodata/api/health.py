from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Response, status
from pydantic import BaseModel

from ecodata.api.dependencies import get_readiness_probe
from ecodata.application.health import ReadinessProbe, readiness

router = APIRouter(tags=["health"])


class LivenessResponse(BaseModel):
    status: Literal["ok"] = "ok"


class ReadinessResponse(BaseModel):
    status: Literal["ok", "unavailable"]
    database: Literal["ok", "unavailable"]


@router.get("/health", response_model=LivenessResponse)
def liveness() -> LivenessResponse:
    return LivenessResponse()


@router.get(
    "/health/ready",
    response_model=ReadinessResponse,
    responses={503: {"model": ReadinessResponse, "description": "Database unavailable"}},
)
def database_readiness(
    response: Response, probe: Annotated[ReadinessProbe, Depends(get_readiness_probe)]
) -> ReadinessResponse:
    report = readiness(probe)
    if report.status != "ok":
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return ReadinessResponse(status=report.status, database=report.database)
