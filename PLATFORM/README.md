# Ecological Data Integration Platform

Initial modular monolith for a PhD research prototype. The runnable scope is an
API, PostgreSQL connectivity, migration tooling and an optional status interface.
Scientific modules and shared dataset/provenance/review services are reserved
packages, not implemented features. No RF01-RF36 compliance is claimed yet.

## Prerequisites

- [uv](https://docs.astral.sh/uv/getting-started/installation/) (tested with 0.11.7).
- Python 3.12+; `uv` can install the version selected in `.python-version`.
- Docker Engine/Desktop with Docker Compose v2 for the full local stack, or a
  separately running PostgreSQL 17 instance for host development.

Run all commands from `PLATFORM/`. On Windows, `Copy-Item` is PowerShell syntax;
use `cp .env.example .env` on macOS/Linux.

## Start the complete stack

```powershell
Copy-Item .env.example .env
docker compose up --build -d
```

Compose waits for a healthy database, runs `alembic upgrade head` in a one-shot
`migrate` container, then starts the API. Inspect startup and readiness:

```powershell
docker compose ps -a
docker compose logs migrate api
curl.exe http://localhost:8000/health
curl.exe http://localhost:8000/health/ready
```

On macOS/Linux use `curl` instead of `curl.exe`.

- [API documentation](http://localhost:8000/docs)
- [Liveness](http://localhost:8000/health): HTTP 200 `{"status":"ok"}`; no DB query.
- [Readiness](http://localhost:8000/health/ready): HTTP 200
  `{"status":"ok","database":"ok"}` after `SELECT 1`; HTTP 503 and
  `{"status":"unavailable","database":"unavailable"}` if DB is unreachable.

Readiness checks connectivity, not schema currency. Compose enforces migration
ordering; host-run startup requires the explicit migration step below.

Optional Streamlit status UI:

```powershell
docker compose --profile ui up --build -d
```

Open [the status interface](http://localhost:8501) and press **Check API and
database**. It uses the API, with no database credentials or processing logic.
The UI is a presentation adapter to the same monolith backend.

Stop while keeping the named PostgreSQL volume:

```powershell
docker compose --profile ui down
```

The default ports are 8000 (API), 5432 (DB), and 8501 (optional UI), bound to
127.0.0.1. `.env` can override `API_PORT`, `POSTGRES_PORT`, and `UI_PORT`.
Existing PostgreSQL volumes retain their initial credentials; changing `.env`
alone does not change an existing database user's password.

## Develop on the host

```powershell
Copy-Item .env.example .env
uv sync --locked
docker compose up -d db
uv run --locked alembic upgrade head
uv run --locked uvicorn ecodata.main:create_app --factory --reload
```

If PostgreSQL is already running, omit the Docker command and set
`ECODATA_DATABASE_URL` in `.env` to its connection URL. The URL must use
`postgresql+psycopg://USER:PASSWORD@HOST:PORT/DATABASE`. URL-encode reserved
characters in credentials. Compose's interpolated URL assumes URL-safe local
credentials. If `POSTGRES_PORT` changes, update the host URL too; containers
continue to use `db:5432`.

Settings read `.env` from the working directory; environment variables override
it. `ECODATA_DATABASE_CONNECT_TIMEOUT` defaults to 3 seconds (allowed 1-30).
Pool checkout and SQL statement timeouts are 5 seconds. The development defaults
are local-only. Authentication, production secrets and TLS are future work.

Run the optional host UI in a second terminal (the uv flag loads `.env` for it):

```powershell
uv run --locked --extra ui --env-file .env streamlit run ui/app.py
```

## Dependencies

| Dependency | Purpose |
| --- | --- |
| FastAPI | HTTP routes, OpenAPI and dependency injection |
| Uvicorn | ASGI server |
| SQLAlchemy 2.x | engine, session lifecycle and future ORM persistence |
| Psycopg 3 with binary extra | PostgreSQL driver without local compiler/libpq setup |
| Alembic | versioned database migrations |
| pydantic-settings | typed environment and .env configuration; Pydantic is supplied by FastAPI |
| pytest (dev) | automated tests |
| HTTPX2 (dev/UI) | supported Starlette test client and optional UI HTTP calls |
| Streamlit (optional `ui` extra) | prototype status interface |
| Hatchling (build only) | package wheel construction from the src layout |

`uv` manages the environment, dependency groups and the committed `uv.lock`.
`uv sync --locked` rejects stale project metadata; Docker uses the same lock and
omits development and UI dependencies in the backend image. There is no parallel
requirements.txt to drift. See [uv's locking documentation](https://docs.astral.sh/uv/concepts/projects/sync/).
The resolved Starlette TestClient uses [HTTPX2](https://pypi.org/project/httpx2/);
this avoids its deprecated HTTPX fallback.
Pandas is not a direct backend dependency; scientific tabular use will be added
with its first use case. The optional Streamlit extra includes pandas transitively. No AI, queue/broker or microservice dependency is installed.

To intentionally update resolution, run `uv lock --upgrade`, review the lock diff
and rerun tests. Normal startup must not update the lock.

## Tests and package checks

```powershell
uv run --locked pytest
uv run --locked alembic upgrade head --sql
uv build
```

The default suite uses isolated configuration, a real local connection refusal,
and small probe doubles for HTTP status branches. Two PostgreSQL integration
tests skip unless an explicit dedicated test database URL is provided. They
create/check the Alembic version table and must not target a research database.

Example with the empty local development database (before storing research data):

```powershell
$env:ECODATA_TEST_DATABASE_URL = 'postgresql+psycopg://ecodata:ecodata@localhost:5432/ecodata'
uv run --locked pytest
Remove-Item Env:ECODATA_TEST_DATABASE_URL
```

For ordinary development, create a separate database and use its URL instead.
The integration tests check real PostgreSQL connectivity, HTTP readiness,
migration idempotence and metadata drift. They do not test ecological workflows.
See [the verification record](docs/development/verification.md) for checks actually
executed in the implementation environment and any limitations.

## Directory structure

```text
PLATFORM/
  .env.example / .gitignore / .dockerignore / .python-version
  pyproject.toml / uv.lock
  Dockerfile / compose.yaml / alembic.ini / README.md
  docs/
    architecture/
      Functional_Requirements_Structured_RF01_RF36.pdf
      ER_01_platform_management_v05.png
      ER_02_canonical_Darwin_Core_v05.png
      initial_skeleton.md
    development/
      implementation_plan.md
      verification.md
  migrations/
    env.py / script.py.mako
    versions/0001_baseline.py
  src/ecodata/
    main.py                         # application factory and wiring
    api/{dependencies,health}.py     # HTTP adapters and schemas
    application/health.py            # readiness use case and explicit probe port
    domain/health.py                 # plain values and errors
    persistence/{base,database}.py   # SQLAlchemy metadata and database adapter
    infrastructure/config.py         # typed environment configuration
    shared/{datasets,provenance,review}/
    modules/
      harvesting/ validation/ harmonisation/ integration/
      export/ analysis/ reporting/   # reserved packages only
  tests/
    test_config.py / test_health.py / test_postgres.py
  ui/app.py                         # optional Streamlit status interface
```

Python package directories include `__init__.py`. `.venv`, caches and build outputs
are local artifacts excluded from version control.

## Architecture and next increments

Read [the architectural decision record](docs/architecture/initial_skeleton.md)
for RF/ER ownership, dependency rules, assumptions and unresolved decisions.
HTTP adapters call application services; domain values contain no framework
imports. The composition root wires persistence implementations to application
interfaces. Future scientific modules expose explicit public application contracts
and must not import one another's internals. Shared services will own datasets,
provenance and user decisions. ORM classes remain in persistence.

Sessions close and roll back unfinished transactions on context exit; future
application use cases must commit explicitly. No `create_all()` runs at startup.
The initial Alembic baseline creates no ER entities. To add a reviewed schema:

```powershell
uv run --locked alembic revision --autogenerate -m "describe the schema change"
uv run --locked alembic upgrade head
```

Register new ORM model modules in `migrations/env.py` before autogenerating and
review every generated migration. No generic repository, event bus or worker
framework exists. Future durable workers can call the same use cases with their
own sessions; job contracts, retries and idempotency need a separate decision.

Remaining work starts with agreed identifiers, dataset version semantics, artifact
storage and an initial dataset/provenance transaction. Add reviewed ER migrations
and shared review services before scientific workflows. Then implement one
vertical slice with research fixtures; progressively add RF01-RF36. Authentication,
permissions, scientific validation policies, canonical Darwin Core profiles,
analysis catalogue, reporting consistency, AI governance and performance budgets
remain unresolved as recorded in the supplied requirements.
