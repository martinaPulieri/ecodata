# Input, configuration and execution contracts (v1 foundation)

The current schema is v2. The original entities below retain these contracts;
see [workspace lifecycle](workspace-lifecycle.md) for the additive migration,
active/removed projection and transactional guards.

## Boundaries

This first increment registers local files, stores immutable interpretation snapshots and records processing intent/history. It supplies APIs for the later Shiny interface. It does not run scientific checks, repair data, harvest data, produce Quarto reports or implement review decisions on findings.

Source code is a flat R package, as approved in the root README. `input_*` owns registration/lexical inspection, `repository_*` owns persistence, and `contracts.R` contains private serialisation/transaction contracts. SQL values use bound parameters; dynamic table identifiers are private constants.

## Persistent entities

| Table | Identity and relationship | Meaning |
|---|---|---|
| datasets | dataset_id | One logical source; later deliveries share this ID. |
| dataset_versions | version_id; dataset_id; optional parent_version_id | Immutable source delivery plus supplied metadata. |
| resources | resource_id; version_id; ordinal | Independent file identity, original name, owned relative path, SHA-256, byte size, declared acquisition status and initial verified copy status. |
| configuration_revisions | config_id; version_id; revision; parent_config_id | Full parser/metadata/schema snapshot, actor/time and canonical payload hash. |
| operations | operation_id; version_id/config_id; unique request_id | Frozen operation intent, submitting actor and R/package/code-version evidence. |
| operation_events | event_id; operation_id; sequence | Append-only lifecycle history with actor, UTC timestamp and reason. |

Every table has BEFORE UPDATE/DELETE triggers rejecting mutation. This is an application integrity contract, not protection against an administrator dropping triggers or changing files directly. The application has no authentication/authorisation layer in this increment; actor IDs are caller-supplied and must not be presented as authenticated identities.

Resources with identical bytes or names remain distinct. An owned copy is only published in the manifest after all copies/hash checks succeed. Errors remove only this registration attempt's generated directory and roll back every database insertion. A process crash between copying and database commit can leave an unreferenced directory; it is not silently registered or automatically deleted. DB transactions and filesystem writes are not a distributed transaction.

Original files remain unchanged. Managed copies are immutable through the public API; hashes are checked before/after inspection and before a new operation submission. Initial `integrity_status = verified` describes the registered copy; `verify_input()` reports its current condition. It does not rewrite the original manifest. Upstream completeness is a separate supplied declaration: complete, incomplete or unknown. Unknown stays unknown; missing source metadata stays missing.

## Version semantics

`register_input(..., parent_version_id=...)` creates a new source delivery in the parent's dataset. Configuration edits create a new revision on the same delivery. Each snapshot is complete: defaults are recorded, and edits must pass all desired parser/metadata/schema values, rather than a partial patch.

The first configuration uses `expected_revision=NULL`; all later saves must supply the displayed current revision. `BEGIN IMMEDIATE` reserves the writer before reading the current revision; stale edits fail instead of overwriting a concurrent revision. Database uniqueness constraints are the second guard.

`confirm_profile()` records an explicit user's declaration and evidence as a new snapshot. It does not prove that declaration true. Unknown/unsupported schemas use generic inspection. The catalogue is versioned as `foundation-1.0`; scientific required/recommended fields are intentionally empty until policy is agreed for the next increment. Severity and applicability vocabularies are defined but no scientific findings are generated.

## Lexical inspection

CSV/TSV previews retain original column order, duplicate headers, leading zeros, literal `NA`, empty values, decimal commas and ambiguous dates. No numeric/date conversion is performed. Column IDs use original positions. Record/table locators are scoped to an input resource and member/row, and must always be used together with the returned config_id: parser changes can change record boundaries.

Defaults are UTF-8, comma for CSV (tab for TSV), double-quote enclosure and decimal point. These are recorded assumptions, not automatically detected facts. Supported explicit encodings are UTF-8, latin1, windows-1252, UTF-16LE and UTF-16BE. UTF-16 decoding operates on raw bytes and strips a decoded initial BOM only in the preview; original bytes remain unchanged. The strict lexer preserves embedded CR/LF/CRLF and rejects quote placement that would otherwise alter content. A header-only table has zero records and zero record IDs. A preview is not a full-file structural or scientific validation. Files exceeding the preview read budget remain registered but receive an inspection limitation.

The subsequent autodetection increment applies supported encoding/separator evidence to new Shiny uploads before saving revision 1. This does not change the low-level explicit defaults or previously saved snapshots. Optional parser_detection evidence is stored in the existing immutable JSON payload, bound to resource byte hashes; no database migration is needed. Manual edits and profile confirmations preserve the evidence without reclassifying manual values as detected. See docs/user-guide/parser-detection.md for bounded rules, ambiguity and explicit redetection of an existing file.

DwC-A ZIP handling validates all directory paths/sizes/counts and resolved member references before opening tables. Repeated references are rejected, so a descriptor cannot bypass the read budget by listing a member repeatedly. It never extracts files to disk, never reconstructs relationships and rejects DTD/entity declarations. Member locations and parser settings come from the immutable meta.xml. Supported descriptor header-line counts are exact integers 0/1; fractional values and unsupported delimiters/encodings are reported explicitly. Explicit row separators must be LF, CR or CRLF and must match the observed terminators; unspecified separators accept native CR/LF/CRLF and are recorded as such. Row-type URIs provide schema candidates only; confirmation is separate. Member previews expose declared fields but do not validate descriptor field/index relationships yet.

Development bounds (configurable at API boundaries, not production capacity claims): 100 input files per registration, 50 MiB each/200 MiB total; 1000 ZIP entries/200 MiB declared expansion; 2 MiB per table preview and 20 returned rows by default. Larger ZIP members are not partially decompressed past the bounded read. Representative workload qualification remains later work.

## Operation lifecycle

`submit_operation()` records queued intent; it never runs an engine. `inspect_input()` is a read-only operation and is not implicitly logged: a coordinating worker submits intent, executes inspection and appends lifecycle events explicitly. The manual script demonstrates that sequence. The reserved validation operation type does not imply a validator has been implemented.

Allowed lifecycle transitions:

```text
queued -> running | cancelled | failed | interrupted
running -> completed | completed_with_limitations | failed | interrupted | cancelled
```

Terminal states cannot restart. A rerun uses a new request_id; previous snapshots/events remain unchanged. Request IDs are repository-wide; retries of the identical frozen request return the original operation, and differing payloads are rejected. A repeated lookup does not pretend to reverify a past execution's current file integrity.

Opening the repository does not modify pending operations: another session may own an active worker. `list_pending_operations()` exposes them for explicit liveness assessment. Automatic worker leases, recovery and scientific completion gates belong to orchestration in a later increment. A trusted worker's completion event is lifecycle evidence, not proof that data passed quality checks.

## Database operations

Foreign keys are enabled per connection, writes use short explicit transactions, WAL supports same-host readers, and a five-second timeout handles transient writer contention. Known Dropbox/OneDrive paths and UNC shares are rejected before filesystem access. Other sync providers/mapped drives cannot be reliably detected: the operator must choose local non-synchronised storage.

Fresh repositories use schema v1. Opening a higher version or unrelated unversioned database is rejected. Migration version checks are made after acquiring the writer reservation, including when another migrator was waiting. A failed future migration rolls back both SQL changes and user_version, with a consistent pre-migration database snapshot taken through a separate reader while writers are excluded. Unknown future migrations are never guessed. WAL negotiation retries SQLite busy/locked responses for at most five seconds during concurrent first opens.

`backup_repository()` uses SQLite's backup API, checks a privately staged copy and publishes it exclusively through a hard link; the destination filesystem must support hard links. Existing destinations are never overwritten, and closed repository handles are rejected before invoking native backup code. A failed copy leaves no partial final backup. A process crash can leave a .lock staging directory, which requires explicit operator inspection rather than automatic removal. Backups do not copy the separate input tree. Disaster recovery needs both database and managed files.

During development the recorded code revision states `uncommitted-development` unless ECODATA_CODE_REVISION is supplied. Package versions are retained; the source diff remains part of the review evidence until the approved commit exists.
