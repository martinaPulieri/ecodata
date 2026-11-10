from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """Shared migration metadata; register future module mappings explicitly."""
