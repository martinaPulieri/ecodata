# Task 2E requirements and acceptance boundary

This increment persists the Tasks 2C/2D subset of RF10/RF12/RF14 and supplies
RF16 interactive result inspection. It does not complete RF08–RF16 or the later
review-decision workflow.

| Deliverable | Implementation | Verification |
|---|---|---|
| Atomic v3 migration with verified backup | 003_validation_results.sql; repository_migrations/connection | v2 backup/reopen, preserved records; existing migration rollback and concurrent migration tests |
| Frozen, idempotent submission | service_validation; shared operation transaction helper | Exact source/config/code/options; duplicate replay; removed-input lookup; generic validation routing; no source byte reads in Run |
| Background execution and ownership | callr/ps worker services | Real child process/independent connection; one claim; active-worker recovery rejection; stopped-worker recovery; competing launcher protection |
| Independent checks and cancellation | Existing engines; family progress; cancellation receipts | Sibling technical failure preserves dates; late cancellation discards records; queued cancellation prevents claims; final progress matches saved outcome |
| Atomic evidence/results persistence | repository_validation_results | Rows/checks/findings/targets/payload plus terminal event; failed insert rollback; source changes during staging; technical failure precedence |
| Responsive result queries | SQL indexes, parameter binding and bulk frames | Stable pagination/filter totals; one append per table; no per-core-key detail in summary JSON |
| Shiny execution and history | mod_validation/results; workspace integration | Source-bound actions, stale events, cross-session pending selection, browser-acknowledged run selection, retained removed-source results |
| Reproducible demonstration | tools/manual-validation.R | Seven date rows, nine linkage outcomes, ten findings; retained after removal, restoration, config revision and restart |

New tests: test-validation-persistence.R, test-validation-worker.R,
test-validation-recovery.R, test-shiny-validation.R and
test-persistent-validation-review.R. Actual final outcomes and browser checks are
recorded in docs/verification/2026-11-26-shiny-validation.md.

Task 2F remains the integrated acceptance gate. General required-field/type
rules, calendar validity, biological duplicate assessment, exports, harmonisation,
integration, complete review decisions and production workload/concurrency
qualification remain outside this increment.
