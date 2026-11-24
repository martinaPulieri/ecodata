# Step 1 traceability and acceptance boundary

This increment supplies the foundation for RF08-RF16; it does not claim full satisfaction of these requirements yet.

| Plan Task 1 deliverable | Implementation | Executed acceptance coverage |
|---|---|---|
| Immutable registration, copies and identities | input_registration.R; resources/datasets/version tables | test-registration.R; test-boundaries.R: original deletion/restart, duplicate names, source lineage, input quotas, tampering and rollback cleanup. |
| Explicit parsing and safe archives | input_parsing.R; input_archive.R | test-inspection.R: duplicate headers, lexical missing markers, quoted/multiline/CRLF values, malformed quotes/rows, header-only tables, TSV, encoding overrides including UTF-16, traversal/expansion limits and repeated descriptor members. |
| Versioned profile/interpretation configuration | input_profiles.R; repository_configuration.R; foundation-1.0.json | test-configuration.R: immutable snapshots, parser resource bindings, schema confirmation evidence, optimistic stale-edit guards and independent connections. |
| SQLite initialisation, migration and backups | repository_connection.R; repository_migrations.R; 001_validation.sql | test-history.R; test-concurrency.R: foreign keys, immutable triggers, future-schema rejection, migration rollback, simultaneous opens/migrations and exclusive backup publication. |
| Traceable operation submission/history | repository_runs.R | test-history.R; test-boundaries.R: exact version/config binding, idempotency, valid/invalid transitions, interruptions, reruns and incomplete acquisitions. |
| Reproducible manual inspection | tools/manual-step1.R; docs/user-guide/manual-step1.md | Demonstrates explicit parser correction, preserved values, two revisions, one idempotent operation, reopen and consistent backup. |

## Deferred functional coverage

RF08 scientific type/format/required-field findings, RF09 geographical validation, RF10 temporal validation, RF11 duplicate detection, RF12 relational scientific checks, RF13 units/measurement checks, RF14 schema-specific rule execution, RF15 external taxonomy and RF16 findings/review UI are not implemented in this increment. Schema declarations and profile prerequisites prepare RF14 but do not execute it. Operation lifecycle events do not certify data quality.

The next approved step can build Shiny and the first structural/relational validator on these contracts. Required/recommended scientific fields and severity thresholds must be agreed before enabling those rules.
