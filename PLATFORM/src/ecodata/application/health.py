from typing import Protocol

from ecodata.domain.health import DatabaseUnavailable, HealthReport


class ReadinessProbe(Protocol):
    def check(self) -> None:
        """Raise DatabaseUnavailable when persistence is unavailable."""
        ...


def readiness(probe: ReadinessProbe) -> HealthReport:
    try:
        probe.check()
    except DatabaseUnavailable:
        return HealthReport(status="unavailable", database="unavailable")
    return HealthReport(status="ok", database="ok")
