# Task 2E: persistent validation and Shiny results

**Publication approval (27 November 2026):** After reviewing Task 2E and its guided
date/timestamp/progress follow-ons, the user approved committing and pushing the
implementation, tests and updated documentation. This supersedes the pre-approval
working-state notes in the execution ledger below.

> Execute inline with superpowers:executing-plans and test-driven development.
> User authorised implementation, tests and documentation; do not stage, commit
> or push before presenting results and receiving separate approval.

**Goal:** Run linkage/date validation from Shiny, keep the interface responsive,
and inspect the same saved assessment after restart or reversible source removal.

**Spec:** Task 2E in 2026-11-23-ecological-platform-validation-first.md; existing
versioned linkage/date rules and contracts. Base: efe5916. Work in the existing
clean feature checkout; preserve the live v2 review runtime during development.

**Architecture:** An atomic v3 migration adds immutable requests, worker claims,
progress/cancellation records, final results, mappings/checks, row classifications,
findings and finding targets. A separate callr process opens its own SQLite
connection and calls existing guarded engines. Shiny submits exact immutable
version/configuration selections, polls progress, and queries paginated persisted
details. Existing Missing information approvals supply confirmed mappings.

**Dependencies:** Existing R/Shiny/SQLite stack plus installed, already locked
callr and ps for supervised worker execution and PID/birth-time liveness checks.

## Constraints and review focus

- No scientific expansion beyond Tasks 2C/2D; recognised dates are not calendar passes.
- Queue intent and frozen request atomically; duplicate keys cannot rerun work or
  adopt changed options. Only one worker can claim an operation.
- Keep long scanning outside Shiny and SQLite write transactions; commit results
  atomically with terminal state. Technical errors stay distinct from findings.
- Independent families survive sibling technical failures. Cancellation retains
  no partial scientific results. Stopped workers require evidenced recovery;
  opening another session must never interrupt an active worker.
- Check stale source/configuration/lifecycle forms; block removal while queued or
  running. Preserve exact historical runs after configuration changes and removal.
- Paginate in SQL, retain original values and frozen provenance, and reconcile
  persisted summary/detail/target counts. No research mapping approvals in demos.

## Implementation steps

- [x] Storage RED/GREEN: migrate v2→v3 with verified backup and rollback; immutable
  append-only tables, atomic submission/finalisation, saved result query/pagination.
- [x] Service RED/GREEN: background process, exact snapshots, worker ownership,
  independent progress, cancellation/failure/recovery, idempotency/removal guards.
- [x] Shiny RED/GREEN: explicit run/cancel/recovery, source-bound buttons,
  mapping-confirmation link, history selection, summary and paginated details;
  correct activity labels and historical/removed browsing.
- [x] Full suite, installed-package check, synthetic restart/removal demonstration,
  independent review and actual desktop/narrow browser workflow; fix findings.
- [x] Update architecture, guide, traceability, roadmap, dependency metadata and
  verification with measured evidence. Show running app/results, leave uncommitted.

## Execution ledger

Ruling: reuse the approved architecture and existing UI styling, adding Validation
and Results tabs. A synchronous run would block Shiny; a new external queue/server
would add unnecessary infrastructure for this local application.
Ruling: use callr/ps already installed and pinned in renv.lock; each worker owns
its connection and only serialisable IDs/options cross the process boundary.
Ruling: keep the existing v2 review app on its runtime until tests pass; demonstrate
v3 in a separate local runtime so old processes cannot write to the upgraded schema.

Implementation and initial synthetic/browser demonstration are complete. Independent
review found nine categories of correctness/responsiveness issues; failing-first
regressions now cover all corrections. Final review-specific set: 34 assertions,
zero failures/errors/warnings/skips. Final source suite: 1,167 passed assertions,
zero failures/errors/warnings/skips. Final installed-package build/check: Status OK,
no warnings or notes. The initial non-ASCII-source warning was resolved using
equivalent Unicode escapes before both final runs.

Corrections: move source hashing into the worker; compare-and-set launcher failure;
protect managed lifecycle transitions; route generic validation to frozen requests
and explicitly cancel legacy intents; recheck source/code after staging; clear stale
counts and persist final progress with results; bulk append once per table; follow
cross-session pending work and retain preferred selection until browser acknowledgement;
omit per-core-key detail from summary JSON. A locale-dependent code fingerprint
discovered by the real-worker test was corrected with radix ordering. Active-process
birth times use POSIXt and unknown liveness is treated conservatively.

The isolated synthetic demonstration and desktop/narrow browser workflows passed,
including actual background Run, cancellation, filtering and persisted results.
The final-source app at http://127.0.0.1:8799 retained four operations after restart
and displayed the saved revision-2 assessment. Architecture, user guide, traceability,
roadmap and measured verification report are updated. Task 2E is ready for user
review; no files have been staged, committed or pushed.
