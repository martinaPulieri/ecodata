# Task 2D: lexical date recognition implementation plan

> **For agentic workers:** Execute inline using superpowers:executing-plans and test-driven development. The user approved committing and pushing Task 2D on 26 November 2026 after reviewing the results.

**Goal:** Execute TMP-00–03/TMP-08 against exact registered tables, preserving text and mapping provenance.

**Architecture:** Pure lexical matching and per-mapping evaluation in R/validation_temporal.R; read-only repository orchestration in R/service_dates.R. Reuse preparation, prerequisites, frozen contexts and typed date records. No Shiny changes or database migration (Task 2E).

**Tech stack:** Existing R package, testthat, SQLite, roxygen2; no new dependencies.

**Spec:** Task 2D in 2026-11-23-ecological-platform-validation-first.md and the pinned ValidationRules.md date rules.

## Constraints and decisions

- User authorised implementation, tests and documentation on 26 November 2026; initially leave changes uncommitted for review. The user subsequently approved commit and push on the same date.
- Work in the existing clean feature checkout, preserving the live app and its runtime. No worktree or branch mutation needed for this bounded increment.
- Keep date-patterns-0.1 and existing saved configuration hashes unchanged. Add an executable date-patterns-1.0 catalogue with the same initial formats; allow explicit selection in new specifications and validate old snapshots against their own version.
- Match ASCII numeric structure and fixed single-field widths exactly, without trimming or calendar/date conversion. Documented order filters year-last candidates; component ranges do not resolve ambiguity.
- Evaluate each mapping independently, including descriptor mappings. Suggestions stay not evaluated. Missing schemas/populations stay unknown.
- Bound total emitted rows across mappings; cancellation or changed source integrity discards affected output. Persist no configurations, operations or scientific results.

## Review focus

Ambiguous numeric dates despite values outside calendar ranges; whitespace/literal NA; reordered split roles and multiple date roles; unreadable sibling members and absent mappings; cancellation, quotas, stale context and restart determinism.

## Steps

- [x] Write and run failing tests for mixed lexical formats, ambiguity/order, split groups and catalogue compatibility.
- [x] Implement matching, scoped contexts and reconciled typed results with per-pattern counts.
- [x] Write and run failing integration/boundary tests; implement read-only run_date_validation() with independent prerequisites, integrity/lifecycle guards, quotas and cooperative cancellation.
- [x] Run focused tests, full regression suite, reproducible synthetic demonstration and installed-package check; review the diff and correct actionable findings.
- [x] Update architecture, user guide, traceability, verification report and milestone status with actual outcomes. No commit or push.

## Execution record

The initial lexical cases passed. Boundary RED/GREEN tests corrected stale population
claims after source changes and latched a one-shot cancellation request.
An independent read-only review found five further issues; each received a
failing-first regression and correction: descriptor precedence over suggestions,
per-row catalogue reloads, targeted early cancellation, descriptor provenance and
nonmissing TMP-02 coverage. Final focused set: 123 assertions, zero failures,
errors, warnings or skips. Final full source suite: 1,051 assertions, zero failures,
errors, warnings or skips. Final built/installed package check: Status: OK, no
warnings or notes. Synthetic demonstration: 18 typed records, identical after
restart, original/configuration hashes unchanged and no engine history writes.

Ruling: keep historical catalogue defaults and add explicit 1.0 selection — preserve
saved hashes/configuration compatibility; callers select 1.0 for new specifications.
Ruling: reuse validated contexts internally while retaining exported API validation
and per-row payload/hash checks — catalogue I/O stays bounded per mapping.
Ruling: Task 2E Shiny/results persistence and workload qualification remain separate;
this increment exposes read-only R services and a reproducible synthetic demonstration.
No review finding was deferred. The implementation was left uncommitted for review;
the user subsequently approved committing and pushing all Task 2D changes.
