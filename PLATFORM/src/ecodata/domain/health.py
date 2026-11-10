from dataclasses import dataclass
from typing import Literal


class DatabaseUnavailable(Exception):
    """The persistence adapter cannot reach the configured database."""


@dataclass(frozen=True)
class HealthReport:
    status: Literal["ok", "unavailable"]
    database: Literal["ok", "unavailable"]
