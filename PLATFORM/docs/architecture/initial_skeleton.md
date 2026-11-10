# Initial modular monolith architecture

Status: initial implementation, 2026-11-10. This is an implementation decision
record, not a replacement for the research requirements or ER diagrams.

## Evidence and scope

All three supplied sources were inspected before choosing boundaries:

- `Functional_Requirements_Structured_RF01_RF36.pdf` (34 pages).
- `ER_01_platform_management_v05.png`: Platform Management v0.5.
- `ER_02_canonical_Darwin_Core_v05.png`: Canonical Darwin Core v0.5.

No referenced source is missing. These are the only original files under
`PLATFORM`; there was no application, dependency convention, or Git repository
at this workspace root. The separate `Martina` project is outside this task.

This increment implements configuration, HTTP health checks, PostgreSQL
connectivity, migration tooling, local deployment and tests. It implements no
scientific RF, authentication, dataset CRUD, canonical records or processing.
Empty packages reserve ownership without pretending that shared services exist.

## Approaches and decisions

1. A single package organised only by technical layer is initially smaller but
   would mix scientific responsibilities as the 36 requirements grow.
2. **Chosen:** one installable Python application with shared capabilities and
   independent scientific packages, with technical layers inside each future
   capability. This retains simple in-process calls and one database.
3. Separate services would add deployment and transaction complexity and conflict
   with the requested modular monolith.

Use Python 3.12+, FastAPI, SQLAlchemy 2 synchronous sessions and Psycopg 3.
Synchronous database routes run through FastAPI's thread pool. Async HTTP is not
a prerequisite for future job workers; workers can call the same application
services with their own session and operation context. No queue, broker, task
framework, generic repository or plugin framework is introduced now.

Use `uv` with standard `pyproject.toml`, a committed `uv.lock`, and a `src` layout.
The lock provides reproducible resolution; dev and optional UI dependencies stay
separate from backend deployment. Docker installs through the same lock.
Pandas is deferred until tabular processing exists. Streamlit is an optional
prototype UI dependency; the status page calls the API and never the database.

## Boundaries and allowed dependencies

- `domain`: framework-independent values and errors; no SQLAlchemy or FastAPI.
- `application`: use cases and narrowly scoped `Protocol` ports; imports domain.
- `api`: HTTP serialization, status codes and dependencies; imports application.
- `persistence`: SQLAlchemy engine/session lifecycle, metadata and database adapter;
  implements application ports without leaking ORM objects into domain.
- `infrastructure`: environment configuration and future external adapters.
- `main.py`: composition root; allowed to import and wire all the above.
- `shared/datasets`, `shared/provenance`, `shared/review`: reserved shared
  capabilities, not a miscellaneous helpers directory.
- `modules/*`: future scientific capabilities; no imports of another module's
  internals. Public application contracts use IDs and explicit input/output values.

The health probe is the only initial port. Module contracts will be added with
actual use cases rather than speculative repository interfaces. A future module
will own `domain/`, `application/`, `persistence/`, and `api/` as required. Workflow
orchestration will call public services; modules must not call each other in
cycles. Database FKs may cross ownership boundaries without Python import cycles.
All ORM mappings will register with the shared SQLAlchemy metadata in Alembic's
environment; metadata discovery must be updated when the first model is added.

## Requirement and entity ownership (planned, not implemented)

| Capability | Requirement coverage | Entity guidance |
| --- | --- | --- |
| `harvesting` | RF01-RF05, RF07 | source adapters, acquisition outputs |
| `validation` | RF08-RF16 | ValidationIssue; review decisions remain separate |
| `harmonisation` | RF17-RF18, RF20-RF24 | MappingProposal, Transformation |
| `integration` | RF25-RF29, RF31 | Reconciliation, ReconciliationMember, ConflictRecord |
| `export` | RF32-RF33 | ExportExecution; EML and dataset output profiles |
| `analysis` | RF34 | AnalysisExecution, preserved results and configurations |
| `reporting` | RF35 | ReportSnapshot and ReportItem; consumes recorded results |
| future AI adapter | RF36 and assisted subrequirements | no package/dependency yet; controlled application calls |
| shared datasets | cross-cutting | Dataset, DatasetVersion, VersionParent, Artifact, VersionArtifact |
| shared provenance | RF06, RF19, RF30 and all operations | WorkflowExecution, Operation, OperationInput/Output, Agent, OperationAgent, ProvenanceRecord; transformation and lineage references |
| shared review | RF16, RF23 and approval-bearing requirements | UserDecision, DecisionTarget; context version and proposal fingerprint |
| future canonical persistence | ER02; harmonisation/integration | CanonicalRecord, EventRecord, OccurrenceRecord, MeasurementRecord, RecordAttribute, SourceRecord, SourceRecordMapping, RecordLineage, AttributeLineage |

Canonical persistence is a shared data representation, not a scientific processor.
Its final package/schema placement remains open until the first canonical use case.
The diagrams show nullable creator operations for legacy versions, multiple version
parents, operation inputs/outputs targeting a version XOR an artifact, typed decision
targets, optional transformation lineage links, and source/internal ID separation.
None of these constraints is replaced with a guessed schema in this increment.

The future workflow must preserve original acquisitions; distinguish incomplete
resources from complete ones (RF07 allows independent completed resources to
continue); keep validation findings separate from decisions; gate integration on
quality assessment; require approval of ambiguous/AI proposals; and preserve
analysis results and immutable report snapshots without recomputation in reporting.
These are design obligations, not implemented behavior or claims of RF compliance.

## Runtime and persistence contract

`GET /health` is process liveness and never contacts PostgreSQL.
`GET /health/ready` runs `SELECT 1` through the configured SQLAlchemy session,
returning HTTP 200 when available and HTTP 503 otherwise. Neither response exposes
credentials or database errors. Readiness proves connectivity, not schema currency.
The application can start during a database outage; it disposes its pool at shutdown.
Each future use case owns its transaction: sessions close/rollback on exit and do
not implicitly commit. No tables are created at import/startup.

Alembic owns schema changes. The initial no-op baseline deliberately creates only
Alembic's version table; ER entities must be introduced through reviewed migrations.
Compose starts a healthy PostgreSQL 17 database, runs a one-shot migration service,
then starts the API. The API is one backend; the optional Streamlit container is a
presentation adapter. Ports bind to loopback for local research development.

## Assumptions and unresolved decisions

The PDF explicitly lists outstanding definitions on pages 32-34. This skeleton does
not settle them silently:

- Internal identifier formats, uniqueness scopes and public API representation.
- Dataset version immutability, branching and downstream invalidation semantics.
- Eligibility, warning and partial acquisition policies beyond the stated RF rules.
- Validation severities, required Darwin Core terms and scientific thresholds.
- Duplicate matching keys, fuzzy thresholds and approved conflict precedence.
- Vocabulary/ontology registries, taxonomic sources, versions and licences.
- Exact Darwin Core core/extension profile; typed attribute storage and indexing.
- Transformation rule library, review queue behavior, rollback, roles and permissions.
- Exact analysis method catalogue, units, missing values and sampling constraints.
- EML version/profile, licences, citation and export packaging constraints.
- Report snapshot consistency, retention, statuses and PDF/JSON schemas.
- AI grounding, permissions and logging; no AI dependency or arbitrary code execution.
- Authentication, authorisation, sensitive ecological data and credential management.
- Dataset volumes, performance budgets, retries, logging and worker scheduling.
- Acceptance fixtures and cross-module contract tests for scientific workflows.
- Editorial RF28/RF29 and legacy RF16/RF17 issues flagged by the source itself.

PostgreSQL 17 and synchronous I/O are prototype defaults, not requirements inferred
from the diagrams. Artifact file/object storage, job durability/idempotency, production
hosting, backup, TLS and access control need decisions before their use cases ship.

## Official repository integration

The initial standalone skeleton was subsequently copied into `PLATFORM/` in
https://github.com/martinaPulieri/ecodata on branch `feature/project-setup`, based
on `main` at `901ac2eeee09d7e2d74fc6aac20c9547cd5d7875`. The repository originally
contained a README and licence. Its two existing commits and licence were
preserved; the root README retains its existing title and description and adds
links to the platform. The separate original workspace and preview remain intact.
Development from this point belongs in the official repository checkout.
