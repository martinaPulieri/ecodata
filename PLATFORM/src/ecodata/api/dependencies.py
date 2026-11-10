from fastapi import Request

from ecodata.application.health import ReadinessProbe


def get_readiness_probe(request: Request) -> ReadinessProbe:
    return request.app.state.database
