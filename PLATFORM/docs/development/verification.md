# Verification record

Date: 2026-11-10 (Europe/Rome).
Environment: Windows, bundled CPython 3.12.14, uv 0.11.7.
Dependencies are resolved in `uv.lock`; backend and optional UI installs succeeded.

| Check | Actual result |
| --- | --- |
| Initial tests before implementation | two collection errors for missing implementation modules |
| `uv run --locked --no-sync pytest` without test DB URL | 10 passed, 2 explicitly skipped; no warnings in final run |
| Full `pytest` with `ECODATA_TEST_DATABASE_URL` | 12 passed against PostgreSQL 17.11 |
| PostgreSQL readiness | real SQLAlchemy/Psycopg connection and `SELECT 1` passed |
| Database outage | refused local connection produced HTTP 503; liveness remained HTTP 200 |
| Alembic integration | upgrade to `0001_baseline`, repeated upgrade, version-table check and `alembic check` passed |
| `alembic upgrade head --sql` | valid PostgreSQL baseline SQL generated |
| Real Uvicorn HTTP | GET `/health/ready` returned 200 and `{"status":"ok","database":"ok"}` |
| OpenAPI over real HTTP | both health routes present |
| `uv build --offline` | source distribution and wheel built successfully |
| Streamlit `AppTest.from_file("ui/app.py").run()` | page rendered with expected title/button and no exceptions |
| Python compilation | source, migrations and UI compiled |
| Independent code review | no important findings |

## Runtime test setup and limitations

Docker and PostgreSQL were not installed on the workstation. To verify actual
PostgreSQL behavior, a temporary password-protected PostgreSQL 17.11 cluster was
started on loopback port 15439 from the Zonky Windows binary test bundle. Its
SHA-256 matched the publisher checksum from Maven Central. This is a test tool,
not a project dependency or an alternative deployment architecture. The Uvicorn
smoke test used loopback port 18039. Both processes were stopped afterwards.

The Windows sandbox prevented PostgreSQL's launcher from creating a restricted
process token. The first launcher also held inherited output handles open; it
was stopped and rerun with file-based logs and approved process permissions.
The successful 12-test run had one pytest cache-writing ACL warning because the
cache was created under the sandbox identity. It affected caching only. The
final default suite under its original identity passed without that warning.

The optional UI was smoke-tested through Streamlit's application test runtime;
its real HTTP button interaction and a full browser session were not tested.
AppTest emits its standard bare-mode ScriptRunContext warning; it reported no
application exception.

**Docker image builds and `docker compose up` were not executed**, because Docker
is absent. Compose ordering, health checks and Dockerfile were reviewed, but their
runtime behavior still needs verification on a Docker-enabled host. No scientific
processing, RF acceptance, production security or performance checks were run;
those functionalities are outside this skeleton.

## Reproduce

```powershell
uv sync --locked
uv run --locked pytest
# Set this to a dedicated empty PostgreSQL test database:
$env:ECODATA_TEST_DATABASE_URL = 'postgresql+psycopg://USER:PASSWORD@localhost:5432/ecodata_test'
uv run --locked pytest
Remove-Item Env:ECODATA_TEST_DATABASE_URL
uv run --locked alembic upgrade head --sql
uv build
```

With Docker installed, complete deployment verification using the README's
`docker compose up --build -d`, then check `/health/ready` and migration logs.

## Official repository checkout verification

After cloning `martinaPulieri/ecodata` and creating `feature/project-setup` from
`main`, the platform was installed in the checkout's own virtual environment.
The imported `ecodata` package path was confirmed to belong to that checkout.
All 12 tests passed against PostgreSQL 17.11, without warnings. Offline migration
SQL generation, Python compilation, source/wheel builds and `uv lock --check`
also passed. Git's staged whitespace check passed. The staged PDF and both PNG
files were verified byte-identical to the original inputs; `.gitattributes`
marks them binary to prevent line-ending conversion. Local environments, caches,
generated datasets and credentials were excluded from the staged file list.
Docker runtime verification remains outstanding.
