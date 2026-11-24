# Manual inspection: input registration, configurations and SQLite history

## Prerequisites and repeatable demonstration

Use R >= 4.4 with the dependencies from renv.lock. Open a terminal in `ecoplatform-r/` in the feature checkout. No Shiny server is expected in this increment. Use synthetic inputs; the script does not read private ecological datasets.

Run:

```text
Rscript --vanilla tools/manual-step1.R
```

Optionally set ECODATA_R_LIBRARY to an already installed development library and ECODATA_MANUAL_ROOT to a **new, local, non-synchronised** runtime directory. The script refuses to reuse an existing directory. It prints the resolved runtime/database paths so they can be opened manually.

Expected console evidence:

1. A two-row preview preserving station IDs `001`, `002`, values `1,5`, `0`, and date strings `03/04/25`, `NA`.
2. PASS messages for unchanged lexical values, idempotent request, rejection of a stale configuration edit, and history recovered after closing/reopening the database.
3. Schema version 1, SQLite integrity_check `ok`, zero foreign-key violations and scientific_checks_executed `FALSE`.
4. Two configuration IDs, one operation ID and the original input SHA-256.

The script writes `artefacts/manual-evidence.json`, `configuration-history.csv` and `operation-events.csv` under the printed runtime. It also creates `backups/history-step1.sqlite` using SQLite's backup API. This is operational acceptance evidence, not the deferred formatted-report feature.

## Inspect the managed original

Open the printed runtime's `inputs/` tree. Filenames are generated resource IDs; the original filename is retained in the resources table. Compare bytes against `tmp/synthetic.csv`: they must match. The script checks the hash and does not convert decimal commas, dates or IDs in the copied bytes.

Optional deliberate-tampering check in a disposable demo runtime: close the app/repository, edit only a managed copy, reopen the repository and call `verify_input(repo, version_id)`. Its overall ok must become FALSE; `inspect_input()` and submission of a new operation must reject integrity failure. Do not modify original research files for this check.

## Inspect SQLite without changing it

Open the printed database in DB Browser for SQLite or another SQLite reader. Prefer a read-only connection, or inspect the closed backup. Execute these queries:

```sql
PRAGMA user_version;
PRAGMA integrity_check;
PRAGMA foreign_key_check;

SELECT resource_id, original_name, sha256, size_bytes,
       acquisition_status, integrity_status
FROM resources ORDER BY ordinal;

SELECT config_id, version_id, revision, parent_config_id,
       actor_id, payload_json
FROM configuration_revisions ORDER BY revision;

SELECT operation_id, version_id, config_id, request_id,
       environment_json
FROM operations;

SELECT operation_id, sequence, status, actor_id, reason
FROM operation_events ORDER BY sequence;
```

Expected: one source delivery and one resource; acquisition_status `unknown`, initial integrity_status `verified`; two revisions, where revision 2 references revision 1; semicolon/decimal-comma settings only in revision 2; one operation bound to revision 2; three events `queued`, `running`, `completed` in that order. Revision 1 still records its original comma/decimal-point defaults. The unknown date convention remains unknown.

Optional immutability check on a **disposable backup copy**:

```sql
UPDATE configuration_revisions SET actor_id = 'changed';
```

Expected error: `immutable history`. Re-query the rows to confirm the actor and snapshots did not change.

## Additional API checks

- Save another revision using an old expected_revision: expect stale revision rejection and no new row.
- Submit the same request_id with the same version/config/actor/type: expect the same operation ID and no duplicate queued event.
- Reuse that request_id with another configuration: expect rejection, preserving the first operation.
- Open a second repository connection: it must not change the first connection's pending operation state.
- Register identical files twice: resource IDs and owned paths differ, hashes can match.
- Register an unsupported format: bytes are retained; inspection says unsupported.
- Register empty/malformed CSV: registration succeeds if the bytes are readable; inspection reports unreadable with a diagnostic. Copy integrity and scientific/readability status are separate concepts.

Automated tests cover all these cases plus interrupted lifecycle events, invalid state transitions, archive path/expansion safety, duplicate descriptor references, exact header/row syntax, per-resource parser isolation, encoding overrides, malformed quotes/embedded CRLF, migration rollback, concurrent first opens/migrations/backups and failed-copy/manifest cleanup.

## Optional check of the supplied ecological examples

Set ECODATA_EXAMPLES_DIR to the original data_examples directory and run:

```text
Rscript --vanilla tools/check-examples.R
```

This registers owned copies in a fresh temporary local runtime, leaving source files unchanged. The script explicitly selects windows-1252/comma for sonda_transizione_2010.csv and UTF-16LE/tab for the Venezia macrozoobenthos CSV. These are technical parser choices supported by inspecting the files; they do not establish units, date conventions or scientific roles.

Expected on the supplied examples: all five files retain verified byte integrity; the three CSVs produce lexical previews; the historical landings DwC-A produces three declared table previews; OBIS_VeniceLagoon.zip is retained with unsupported status because it has no single recognised meta.xml. An unsupported archive is not reconstructed or silently treated as validated.

## Limitations for this review

There is no authentication, Shiny upload interface, scientific validation, review of findings, harvesting or Quarto reporting yet. The preview is bounded, not a whole-dataset check. Unknown metadata is not inferred. Data and DB are separate backup units. A crash can leave unreferenced owned copies, which are retained for explicit recovery inspection. Worker liveness/recovery is explicit, not automatic.
