FROM ghcr.io/astral-sh/uv:0.11.7 AS uv
FROM python:3.12-slim AS base
COPY --from=uv /uv /uvx /bin/
WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never
COPY pyproject.toml uv.lock README.md ./
COPY src ./src
COPY alembic.ini ./
COPY migrations ./migrations
RUN uv sync --locked --no-dev --no-editable
ENV PATH="/app/.venv/bin:$PATH"
RUN useradd --create-home --uid 10001 ecodata

FROM base AS ui
RUN uv sync --locked --no-dev --no-editable --extra ui
COPY ui ./ui
USER ecodata
CMD ["streamlit", "run", "ui/app.py", "--server.address=0.0.0.0", "--server.port=8501"]

FROM base AS api
USER ecodata
EXPOSE 8000
CMD ["uvicorn", "ecodata.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000"]
