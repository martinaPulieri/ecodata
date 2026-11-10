# Platform Skeleton Implementation Plan

**Goal:** a runnable modular monolith foundation with database readiness checks.
**Architecture:** one backend, one PostgreSQL database, explicit health port and
reserved shared/scientific capabilities. No processing or ER schema invention.
**Tech stack:** Python 3.12+, uv, FastAPI, SQLAlchemy 2, Psycopg 3, Alembic, pytest.
**Spec:** `../architecture/initial_skeleton.md` and the user's implementation request.

The user requested direct repository implementation; execution stays in this
session. There is no Git repository to branch or commit. Original documents and
the separate Martina directory remain untouched.

## Tasks

- [x] Add project metadata, optional UI group and isolated environment. Write tests
  for API liveness, database readiness success/failure and configuration validation.
  Run them before production implementation and record the initial failure.
- [x] Implement `create_app(settings: Settings | None = None) -> FastAPI`,
  `ReadinessProbe.check() -> None`, `readiness(probe) -> HealthReport`, and
  `Database(settings)` with SQLAlchemy sessions. Verify tests, including real
  connection refusal without leaking secrets and per-app configuration isolation.
- [x] Add empty capability packages, Alembic baseline, Dockerfile, Compose and an
  optional Streamlit status interface. Provide PostgreSQL integration tests that
  run only when `ECODATA_TEST_DATABASE_URL` is explicitly configured.
- [x] Lock dependencies, document installation, startup, dependency purposes,
  architecture and remaining work. Verify package build, migrations and full test
  suite; attempt real PostgreSQL/HTTP verification with available local tools.

## Review focus

Liveness must survive database outages. Readiness must fail closed with HTTP 503,
not return an unconditional OK. PostgreSQL URLs must select Psycopg 3 explicitly.
App factories must not share pools/settings. Database secrets must not appear in
health responses. Migration execution must precede API startup in Compose.
Integration tests must not silently target the development database.

## Execution record

- All three source documents inspected; none missing.
- Docker, PostgreSQL and a user-installed Python are absent; bundled Python 3.12.14
  used for verification. Dependencies install into `PLATFORM/.venv`.
- Ruling: implement in the requested directory without Git operations because this
  workspace is not a Git repository. No unrelated project files are changed.

- Initial red run: two missing-module collection errors before implementation.
- Initial green run: 10 passed; default suite after integration-test addition: 10 passed, 2 skipped.
- Ruling: use HTTPX2 for test/UI clients because the resolved Starlette TestClient explicitly deprecates HTTPX; verified against installed source and the upstream PyPI package. This avoids a deprecated integration without adding a second HTTP client.
- Portable PostgreSQL pg_ctl cannot create a restricted token inside the Windows sandbox (error 87); runtime verification will run with the approved process permissions.

- Final default suite: 10 passed, 2 explicitly skipped (no test database URL).
- PostgreSQL 17.11 integration suite: all 12 passed, including migration idempotence and metadata drift. One Windows pytest cache ACL warning affected cache writing only.
- Real Uvicorn HTTP readiness returned 200; OpenAPI contained both health routes.
- Streamlit AppTest rendered the initial UI without exceptions.
- Source/wheel builds and offline migration SQL generation passed.
- Independent read-only review found no important findings. Docker runtime remains unavailable; no image/Compose execution is claimed.
- Temporary database and API processes were stopped after verification.
