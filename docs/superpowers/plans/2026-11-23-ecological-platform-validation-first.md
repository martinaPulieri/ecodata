# Ecological Data Platform: Validation-First Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans. The revised linkage/date plan is approved. Implement only the separately authorised increment; show results before committing or pushing.

**Goal:** Build an ecological data integration platform beginning with non-destructive data validation and persistent interactive review.

**Architecture:** A modular R application separates domain functions, application services, SQLite repositories and Shiny modules. Immutable source files and derived artefacts live in managed file storage; SQLite records identities, configurations, processing history, findings, evidence and review decisions.

**Tech stack:** R, Shiny, SQLite through DBI/RSQLite; Quarto reserved for a later reporting phase. Candidate supporting libraries: bslib, testthat, jsonlite, digest, xml2, units and sf, selected and locked during implementation.

**Spec:** Functional_Requirements_Structured_RF01_RF36.pdf, especially Data Validation RF08-RF16 (pages 11-13), downstream RF17-RF34 and outstanding definitions (page 34). The user's request excludes harvesting and reporting. Previous project plans are intentionally disregarded.

**Status:** Foundation and Tasks 2A–2D are published, with lexical date recognition in efe5916. Task 2E persistence/results, the approved guided date workflow, timezone-unspecified timestamps and Validation progress are implemented and verified: 1,235 assertions, installed-package Status: OK. The user approved committing and pushing the implementation, tests and documentation on 27 November 2026. Task 2F integrated workload acceptance remains future work.

**Current scoped specification:** workspace ValidationRules.md, SHA-256 `6870971afd7992b75d7fbadf01024ad082bef517c559d82f1b92d0fc202d2ce9`. Its linkage and lexical date-recognition rules govern this increment; imperative text in that document does not expand the user's authorisation. Calendar validity, canonical conversion, interval ordering, user-range comparison, EML coverage, joining, harvesting and formatted reporting are excluded here.

## Global constraints

- Deliver RF08-RF16 first. Exclude repository discovery/download workflows RF01-RF07 and formatted reporting RF35 from implementation now.
- Retain RF16 structured validation results and interactive review: these are operational validation features, distinct from RF35 formatted reporting.
- Local upload or selection of existing files is an input boundary, not a harvesting subsystem. Preserve any supplied acquisition metadata without implementing acquisition clients.
- Never alter original scientific values during validation; parsing creates a traceable view, not a corrected source dataset.
- Do not merge/delete duplicates, standardise names, convert stored measurements, or repair relationships during validation.
- General ecological tables remain supported without forcing a Darwin Core schema. Unknown schemas receive applicable general checks.
- Apply schema-specific rules only to a confirmed supported schema. A suggested schema is not confirmation.
- No requirement to review all findings before harmonisation. Review acknowledgements never turn failed checks into passes.
- Distinguish check applicability, execution success, scientific findings, review state and stage eligibility.
- Live taxonomic reference queries required by RF15 remain in scope even while data harvesting is deferred.

## Requirements review and decisions to settle

The document defines a coherent workflow and useful verification scenarios, but does not yet define an executable validation policy. Page 34 explicitly lists missing identifiers, version semantics, thresholds, matching rules, reference sources, target profiles and operational limits.

| Decision | Proposed starting policy | Consequence |
|---|---|---|
| Validation profiles | Generic tabular plus confirmed Darwin Core Occurrence/Event/measurement profiles | Required fields are profile-specific; generic ecological tables are not rejected for lacking occurrence fields. |
| Input formats | CSV/TSV and DwC-A ZIP first; retain unsupported files with an explicit limitation | A bounded initial scope, without claiming all ecological formats are supported. |
| Severity | Critical, warning, information; assigned by versioned rule/profile | Severity describes scientific/structural impact, not execution failure. |
| Missing context | Return an explicit prerequisite limitation | No inferred CRS, units, observational unit or sampling protocol. |
| Review vocabulary | Acknowledge, needs harmonisation, disputed, deferred; optional comment | These annotate evidence; they do not authorise a correction. |
| Input versions | Immutable bytes plus parser/configuration revisions | A parser correction creates a new interpretation/run, retaining the old history. |
| Resource completeness | Record supplied complete/incomplete/unknown status and evidence; technical integrity separately | A checksum does not prove upstream acquisition completeness. Incomplete resources cannot appear complete; complete independent resources can proceed. |
| Scale and users | Start with one host and bounded workloads; measure limits on representative data | No unsupported multi-host or production-capacity claims. |

Before the first scientific milestone, agree the required/recommended fields per profile, accepted date conventions, reference CRS handling, variable/unit rules, geography reference layers and versions, duplicate keys and taxonomic matching policy. Treat these as configuration decisions, not implicit package defaults.

Editorial clean-up: the PDF contains stray text and a legacy RF28/RF29/RF16/RF17 terminology note. Use the current workflow-aligned IDs and titles for traceability; clarify the legacy note before migration to any older requirements catalogue.

## Architecture choice

1. **Recommended: modular R application with reusable domain functions.** Lowest initial operational burden for Shiny/SQLite; domain functions can later serve batch jobs or an API.
2. **Shiny plus a separate processing API.** Better separation for independently scaled workers, but adds deployment/authentication/queue contracts before workload needs are established.
3. **Large Shiny server containing all logic.** Quick demonstration, but makes scientific checks, persistence and reproducibility difficult to test independently; unsuitable for the intended platform.

The modular R package architecture and flat R/ source layout are approved and implemented. The separate API and large-server alternatives are not selected.

Processing path: local input -> immutable registration -> parser inspection and explicit configuration -> schema confirmation -> versioned validation run -> persisted results -> interactive review -> later harmonisation.

### Persistence model

| Entity | Principal contents |
|---|---|
| workflows | workflowExecutionID, owner/actor, creation time |
| datasets / dataset_versions | datasetVersionID, parent version(s), version manifest, metadata references |
| resources | immutable file ID, owned path, original filename, SHA-256, size, declared acquisition status |
| configuration_revisions | parser settings, schema evidence/confirmation, semantic bindings, metadata, profile/ruleset versions |
| operations / operation_inputs | operationID, exact input versions, request ID, configuration snapshot, code/environment version, timestamps, status |
| check_executions | rule ID/version, applicability, execution state, evaluated population/counts, limitation/failure reason |
| findings / finding_targets | resultID, rule, severity, explanation/evidence; one or many version-bound record/field/table targets |
| duplicate_groups / members | candidate class, members across source versions, evidence and matching-rule version |
| reference_queries / responses | service, release/context, request parameters, retrieval time, response hash/path, outcome |
| review_decisions | decisionID, result/proposal target, actor, action, reason, timestamp, supersedes ID, context hash |
| artefacts / lineage_edges | immutable outputs, hashes, input/output links; later transformation and record/attribute lineage |

Use internal record locators scoped to resource version, table and row position; preserve source IDs as attributes. Missing or duplicate source IDs must not prevent findings from identifying records. Decision revisions append events; the current decision is a projection of history. Bind bulk decisions to an explicit recorded member set and reject stale-context writes.

Use foreign keys, indexed result filters, transactions and idempotent submission IDs. Persist successful partial check outcomes, but label interrupted runs and unevaluated checks explicitly. Publish a completed result set only when its declared checks have reached terminal states. A restarted app detects interrupted operations; reruns create linked operations rather than overwrite history.

Keep the active SQLite database on a local, non-synchronised disk; back up consistent snapshots into the project/backup location. This matters because the workspace is in Dropbox. Use short write transactions, a busy timeout, one controlled writer and WAL where appropriate on the same host. Do not share one live database across synchronising clients.

### Result and state contracts

- Applicability: applicable, not_applicable, prerequisites_missing.
- Check execution: not_started, running, completed, failed, interrupted, cancelled.
- Completed assessment: findings present or none found, with evaluated record counts. A successful execution may detect critical findings.
- Run execution: queued, running, completed, completed_with_limitations, failed, interrupted, cancelled.
- Review: unreviewed or the latest explicit decision; independent of all above states.
- Eligibility: calculated for a named downstream stage and policy version; never equated with review completion.

At validation-to-harmonisation handoff, unreviewed findings are permitted. A stage may still be unable to consume an unreadable input. Later RF24/RF26 and RF31 explicitly block integration/analysis eligibility on critical issues or incomplete mandatory checks, while non-critical warnings do not automatically block progression. Keep these gates separate.

### Proposed source layout and interfaces

```text
app.R
R/input_*.R         registration, safe archives, parsing, metadata, schema profiles
R/validation_*.R    rule catalogues, contracts, independent domain checks
R/service_*.R       submission, orchestration, review, eligibility
R/repository_*.R    SQLite migrations, runs, findings, decisions, references
R/mod_*.R           Shiny modules; app_ui.R and run_app.R assemble the app
inst/sql/           numbered migrations
inst/profiles/      versioned profiles and rule configurations
tests/testthat/     unit, repository and service tests
tests/fixtures/     synthetic data and recorded external responses
```

- `register_input(paths, metadata, repo)` -> immutable dataset-version reference and resource statuses.
- `inspect_input(version_id, parser_config)` -> tables, original columns, bounded preview, parser diagnostics and schema candidates.
- `confirm_profile(version_id, profile_id, evidence, expected_revision, repo)` -> new configuration revision.
- `validate_dataset(input_view, context, rule_set)` -> check executions, findings and evidence, without UI/database writes.
- `submit_validation(version_ids, config_revision_ids, request_id, repo)` -> operation ID; supports explicit cross-dataset duplicate scope.
- `save_review(result_ids, action, reason, actor_id, expected_context, repo)` -> append-only decision IDs.
- `query_findings(operation_id, filters, page, page_size, repo)` -> paginated findings and counts.

## Review focus

1. Parser conventions or missing metadata must not silently invent scientific meaning; test ambiguous dates, decimal commas, unknown CRS/units and two-digit years.
2. Similar observations must not be falsely identified as the same record; test repeated sampling, cross-source ID collisions and matching tolerance boundaries.
3. Interrupted services or unsupported checks must never appear as passing; test reference-service outages, partial responses and application restart.
4. Review decisions must not leak across versions, files or concurrent sessions; test same filenames, duplicate IDs and stale bulk actions.
5. Original values and history must survive every operation; test source hashes, transactional rollback, reruns and decision revisions.

## Implementation tasks and acceptance gates

For each task: establish independently specified fixtures and expected results, observe the relevant failing tests, implement the slice, run its targeted checks and affected regression tests, then record requirement coverage. No production code is included in this proposal.

### Task 1: Validation policy, registration and history foundation

**Files:** R/input_registration.R, R/input_parsing.R, R/input_profiles.R; R/repository_connection.R, R/repository_migrations.R, R/repository_runs.R; R/contracts.R; inst/sql/001_validation.sql; inst/profiles/*.json; corresponding test files.

**Interfaces:** produces register_input(), inspect_input(), confirm_profile() and the versioned input/result contracts consumed by Tasks 2-6.

- [ ] Define and version profiles, required-field rules, severities, applicability and state transitions.
- [x] Implement managed immutable copies, hashes, file/table/record identities, safe ZIP inspection and reproducible parser settings (bounded lexical preview, not full-table validation).
- [x] Implement migrations, immutable configuration revisions and traceable run submission; record supplied provenance gaps.
- [x] Test clean and malformed files, encoding/delimiter overrides, empty input, unsupported formats, archive traversal/size bounds, duplicate filenames, restart and migration rollback.
- [x] Deliver Shiny registration/configuration/history, automatic format detection and reversible source-version removal (schema v2).

**Gate:** Register and reopen inputs; reconstruct their exact bytes, parser settings and metadata without changing originals. No schema-specific rules execute without confirmation.

### Task 2: Declared archive linkage and lexical date recognition

The next validation increment covers PRE-01, LNK-01–08, TMP-00–03 and TMP-08. It is a subset of RF08/RF10/RF12/RF14/RF16, not completion of those requirements. Keep the normal upload, file selection and preview behaviour.

#### Task 2A: Versioned rules, mappings and result contracts — authorised now

**Files:** R/validation_catalogues.R, R/validation_mappings.R, R/validation_context.R, R/validation_results.R; R/repository_configuration.R; inst/rules/*.json; tests/testthat/test-validation-*.R; docs/architecture/validation-contracts.md; tools/manual-validation-contracts.R.

**Interfaces:** versioned rule/pattern catalogue readers; constructors for source-scoped tables, date and descriptor linkage mappings; new_validation_spec(); freeze_validation_context(); typed check/date/linkage result constructors and reconciliation summaries. These define data contracts, not a rule engine.

- [x] Write failing tests for all 14 rule definitions, pinned versions/hashes, unknown versions, mapping identity/column validation, exact retained values, JSON round trips, typed result invariants and status counting.
- [x] Provide immutable rule definitions and a provisional pattern catalogue, distinguishing linkage errors/warnings/information from date classification statuses and technical execution states.
- [x] Store explicit mappings and complete catalogue snapshots in append-only configuration payloads. Preserve them through parser edits, redetection and profile confirmation; reject stale/removed writes. Existing configurations remain readable without inventing validation metadata retroactively.
- [x] Bind mappings to version/resource/table, original headers and zero-based column positions. Split date roles are named, never inferred from physical order; suggested mappings cannot claim confirmation. Confirmed date order requires recorded evidence.
- [x] Freeze input/configuration/catalogue context for future runs; validate result shapes, row locators, candidate cardinality and mutually exclusive per-row counts independently of Shiny/database writes.
- [x] Run manual synthetic contract demonstrations, regression tests and package check. No full-table reader, scientific checks, new results tables, validation button or automatic classifications in this slice. No commit/push before separate approval.

**Gate:** Definitions, mappings and synthetic result records survive serialisation and repository restart without changing originals or old configuration hashes. Contracts reject inconsistent counts, invalid identities and unsupported catalogue references. A recorded mapping is a declaration: actual table/header/index prerequisites are checked by Task 2B, not falsely certified here.

**Verification (25 November 2026):** 463 assertions passed; installed-package check Status: OK. Synthetic contract demonstration preserved hashes/context after restart. The user explicitly approved publication of the amended plan, code, tests and documentation. See ecoplatform-r/docs/verification/2026-11-25-validation-contracts.md.

#### Task 2B: Full-table reading and independent prerequisites — implemented, publication approved

**Files:** R/input_validation_tables.R, R/input_validation_archive.R, R/input_parsing.R, R/validation_structure.R, fixtures/tests, generated API help and tools/manual-full-tables.R.

- [x] Add full-table processing separate from the bounded preview, retaining logical record locators and decoded strings without trimming, numeric/date conversion or literal-NA coercion.
- [x] Resolve meta.xml member settings, core id/coreid indices (including 0), field terms, original headers/positions and supported declaration evidence. occurrenceID is not a substitute for the declared core key.
- [x] Run PRE-01/LNK-01 and TMP-00 with member/family-specific prerequisites. A failed extension must not disable independently readable dates.
- [x] Verify saved mapping schema against the actual table. Report quotas, partial scans and interrupted work explicitly; never label a preview as full coverage.


**Implementation boundaries:** Read-only preparation contracts validation-preparation-1.0 and validation-prerequisites-1.0; SQLite stays v2. Default per-table quotas: 50 MiB, 1,000,000 data rows and 5,000,000 decoded fields, with a separate 1 MiB descriptor quota. In-memory processing and cooperative cancellation are explicit. ready denotes prerequisites only; scientific_rows_evaluated remains zero. Saved mappings override covered positions while independent descriptor fields remain available. No 2C/2D engine or 2E UI/persistence is included.

**Verification:** See ecoplatform-r/docs/verification/2026-11-25-full-table-prerequisites.md for real-input inventories, regression/package checks, independent review and manual instructions. No commit/push before separate user approval.

#### Task 2B extension: Missing-information clarification — implemented, publication approved

User authorised a Shiny clarification workflow for heterogeneous input metadata.
Questions explain missing prerequisites and dependent checks; suggestions stay
unapproved until exact draft review and explicit approval. Approved answers are
stored in append-only configuration JSON with source/configuration scope, values,
operator/time and evidence. Parser, date and missing archive-key answers update
their corresponding prerequisites; source-repair notes stay pending. Independent
fields continue to require their own answers. Mapping replacements are explicitly
shown for approval and retained in historical revisions.

Files: R/clarification_questions.R, R/service_clarifications.R,
R/mod_clarifications.R, compatible configuration/mapping/prerequisite updates,
Shiny integration, tests, generated help and tools/manual-clarifications.R.

Verification: 662 assertions; installed-package Status: OK; real Venezia 468 x 235,
two date questions left pending with zero invented semantic approvals; synthetic
approval/restart verified. Visual browser inspection blocked by Windows sandbox
error 1920; automated Shiny module checks passed. See
ecoplatform-r/docs/verification/2026-11-25-clarifications.md.
No scientific engine/results persistence is included; no staging/commit/push
before separate user approval.

#### Task 2B extension: ZIP collections without meta.xml — implemented, publication approved

User authorised ordinary ZIP dataset support, starting with OBIS. CSV/TSV/TXT
members are read independently; ignored sidecars are never executed. Descriptor
archives retain their existing route, including explicit failure for present
invalid descriptors. Uncertain member settings/header presence require exact
approval and are versioned under archive_settings with clarification receipts.
Candidate loaded rows do not certify an assessed population before approval.
Generic table/key relationships are source=user and require explicit approval;
date prerequisites remain independent of linkage.

Verification: 772 assertions; installed-package Status: OK. Real OBIS produced
5,831 x 282 and 2,762 x 15 candidate tables with 20-row previews; no real
settings/mappings were approved. Synthetic approvals produced revision 5 and
survived restart. Windows non-BMP Unicode phantom records and a UTF-8 extraction
performance issue were reproduced and corrected. See
ecoplatform-r/docs/verification/2026-11-25-plain-zip.md.
No staging, commit or push before user approval. Matching approved generic ZIP
relationships belongs to the Task 2C linkage engine below; no
matching, date recognition or scientific result persistence is executed here.

#### Task 2C: Exact linkage and key-scope diagnostic — implemented, publication approved

**Files:** R/validation_identifiers.R, R/service_linkage.R, R/validation_linkage_scope.R; fixture/engine/scope/review tests, generated R help, architecture/manual guide and tools/manual-linkage.R.

- [x] Implement LNK-02–06 as mandatory when applicable; LNK-07/08 are supplemental. Compare nonmissing strings exactly; empty/whitespace-only keys are missing, while literal NA remains a value unless a documented profile says otherwise.
- [x] Produce one measurement outcome: uniquely linked, ambiguous, missing reference, unresolved reference or not evaluated. Use lookup counts rather than a row-multiplying join.
- [x] Keep repeated-key group/affected-row counts, legitimate many-measurement multiplicity, coverage and visible whitespace evidence separate.

**Additional approved check:** Compare OBIS id versus dataset_id + id without automatic adoption. The canonical-reader comparison found 5,831 unique IDs across 29 datasets and 2,762 uniquely resolved references under both candidates, with zero namespace conflict. A composite execution contract was not required for this observed snapshot; synthetic tests detect when a namespace would be required or insufficient.

**Verification:** 928 assertions; installed-package Status: OK; synthetic outcomes and canonical OBIS comparison reproduced; originals/configurations/history unchanged. Quotas/cancellation, absent saved mappings, source races and independent resources covered. No scientific date recognition, new results tables or results UI in this slice. See ecoplatform-r/docs/verification/2026-11-25-linkage-engine.md. The user approved staging, commit and push of Step 2C on 25 November 2026.

#### Task 2D: Lexical date patterns — implemented, publication approved

**Files:** R/validation_temporal.R, R/service_dates.R, versioned inst/rules/date-patterns-*.json, typed result/catalogue compatibility updates, tests, API help and tools/manual-dates.R.

- [x] Implement TMP-00–03/TMP-08 per confirmed field/group, with one classification per input row and mapping. A suggested field requires confirmation; a usable descriptor retains declaration provenance.
- [x] Recognise enabled numeric dates, partial dates, timestamps, explicit intervals and split numeric components. Preserve every structurally compatible candidate when date order is undocumented. Record endpoint patterns for intervals and missing components for incomplete groups.
- [x] Reconcile recognised/ambiguous/unrecognised/missing/incomplete/not-evaluated totals. 2020-02-30 is lexically recognised as YYYY-MM-DD, with no calendar-validity claim.

**Implementation boundary:** Read-only date-evaluation-1.0/lexical-dates-1.0 services;
SQLite stays v2. Existing 0.1 catalogue snapshots remain unchanged; 1.0 is explicitly
selectable for new specifications. Full-table date execution is independent of
linkage, with confirmed mapping/schema checks, a shared output budget, cooperative
cancellation, resource integrity and lifecycle guards. No Task 2E UI/persistence.

**Verification:** See ecoplatform-r/docs/verification/2026-11-26-lexical-dates.md
for executed checks, the two-role synthetic demonstration, review corrections and
remaining scientific limitations. Final suite: 1,051 assertions with zero failures,
errors, warnings or skips; installed-package Status: OK. User authorised implementation/tests/docs on
26 November 2026 and subsequently explicitly approved committing and pushing
the implementation, tests and updated documentation on the same date.

#### Task 2E: Persistence and Shiny results — implemented and approved for publication

**Files:** inst/sql/003_validation_results.sql, R/repository_validation_results.R, R/service_validation.R, R/mod_validation.R, R/mod_validation_results.R and tests.

- [x] Atomically migrate v2 to v3 with verified backup; persist check coverage, findings/targets, date classifications and frozen context.
- [x] Add mapping confirmation, explicit Run, independent progress, summary and paginated details using one structured result for later review/downloads. Distinguish technical failures from findings.
- [x] Move full-table work outside the interactive request with frozen inputs and short SQLite writes. Reuse idempotency, lifecycle revisions and queued/running removal protection. Retain historical results for removed inputs.

**Implemented boundary:** Shiny Validation/Results tabs use exact saved selections,
existing explicit mapping approvals and supervised callr workers. Immutable v3
requests, claims, progress, cancellation and normalised evidence preserve restart,
configuration and removed-source history. Source byte checks run in workers;
post-staging integrity verification, worker ownership and atomic bulk persistence
prevent partial/contradictory results. Review regressions cover cross-session and
launcher races, legacy intents, cancellation, source changes and bounded summaries.

**Verification:** See ecoplatform-r/docs/verification/2026-11-26-shiny-validation.md
for final tests/checks, independent review corrections and live browser evidence.
Results were presented before publication. On 27 November 2026 the user approved
committing and pushing the implementation, tests and documentation, including the
subsequent guided workflow and timestamp/progress fixes. Task 2F remains separate.

#### Task 2F: Integrated acceptance — future

Approved follow-on UI flow (27 November 2026): preview embedded in reading
configuration, combined save/preview, automatic Next information check, bullet date
field/format declarations and dates-only exact-format validation. Implementation
and review evidence: [date workflow verification](../../../ecoplatform-r/docs/verification/2026-11-27-date-workflow.md).
The user approved this follow-on implementation for commit/push on 27 November 2026.

- [ ] Execute every ValidationRules.md synthetic example, multiple roles, unconfirmed mappings, mixed formats, split/reordered components, leading zeros, absent members and independent-family execution.
- [ ] Reconcile summary/detail counts; test original hashes, restart, cancellation/interruption, stale forms, multi-source/session isolation, migration and manual/browser checks.
- [ ] If the exact Occurrence_Measures_Example1.zip is available, measure its inventory against 8,480 occurrence and 2,916 measurement rows, then report observed findings separately. Do not apply these counts to other archives or invent reference findings.

**Increment gate:** Full selected populations evaluated or explicit coverage limitations; original data unchanged; all enabled outcomes/results reproducible from frozen context. General required-field/type checks, biological duplicates, scientific calendar validation and full review-decision workflow remain later work.

### Task 3: Geography and time — RF09, RF10

**Files:** R/validation_geography.R, R/validation_temporal.R; versioned spatial reference manifests; dedicated fixtures/tests.

- [ ] Check coordinate lexical/numeric format, complete pairs, ranges and confirmed CRS prerequisites.
- [ ] Assess country/country-code and marine/terrestrial consistency using versioned reference layers; disclose coastline resolution/tolerance and uncertainty.
- [ ] Define and implement calendar validity, interval ordering, cross-field consistency and metadata coverage in a later increment. Lexical date recognition is brought forward to Tasks 2A–2F and does not satisfy this scientific gate.
- [ ] Test poles/dateline, zero coordinates, absent CRS, coastline ambiguity, leap days, ambiguous day/month conventions, partial-date intervals, timezones and out-of-coverage records.

**Gate:** Suspicious geography is explained; coordinates are not swapped or transformed in source data. Partial dates are not assigned invented precision; unresolved conventions remain explicit.

### Task 4: Measurements and duplicate candidates — RF13, RF11

**Files:** R/validation_measurements.R, R/validation_duplicates.R; R/repository_duplicate_groups.R; versioned variable constraints; fixtures/tests.

- [ ] Validate values, known units, dimensional compatibility and documented variable constraints; retain zeros, missing markers and censored expressions distinctly.
- [ ] Detect exact and potential duplicates within/across explicitly selected versions using source-scoped identifiers and documented attribute rules.
- [ ] Store duplicate groups, evidence and member links; use indexed blocking strategies rather than unbounded all-pairs comparison.
- [ ] Test missing/unknown/incompatible units, context-dependent quantities, below-detection values, exact duplicates, source-ID collisions and scientifically distinct repeat observations.

**Gate:** No unit conversion, deletion or merge occurs. Every duplicate candidate explains its evidence and scope. Unit compatibility alone does not establish comparability of sampling methods.

### Task 5: Taxonomic evidence — RF15

**Files:** R/validation_taxonomy.R; R/reference_checklistbank.R, R/reference_worms.R, R/reference_cache.R; recorded-response fixtures and tests.

- [ ] Flag abbreviations, qualifiers such as cf./aff., and nomenclatural annotations without deleting their information.
- [ ] Implement separately tested ChecklistBank/Catalogue of Life and WoRMS TaxaMatch adapters; confirm current endpoints, authentication, quotas and match semantics during an initial capability probe.
- [ ] Deduplicate equivalent requests using name plus relevant authority/rank/classification context, reference release and matching parameters; do not collapse distinct ambiguous queries.
- [ ] Retain candidate matches, accepted/synonym status, conflicts, unmatched results and source-record links; cache query/response evidence with retrieval time and source version when available.
- [ ] Test accepted names, synonyms, ambiguous names, conflicting services, repeated requests, qualifiers, timeouts, rate limits and unavailable version metadata using recorded responses.

**Gate:** Repeated equivalent queries reuse evidence; service failures produce an incomplete assessment, not an unmatched taxon or a pass. Original identifications remain unchanged. A pinned cached-evidence run is reproducible; a live rerun may differ and must record new reference context.

### Task 6: Complete validation release — RF08-RF16

**Files:** R/service_orchestration.R, R/service_eligibility.R; R/repository_query_indexes.R; Shiny progress/results/history modules; end-to-end fixtures and acceptance matrix.

- [ ] Assemble multi-file and cross-dataset scope, independent check failures, persisted progress and idempotent submissions.
- [ ] Move long operations into a background worker, passing frozen inputs; keep Shiny reactive values out of domain workers and coordinate short SQLite writes.
- [ ] Add paginated record inspection, check status/coverage summaries and explicit scoped bulk review.
- [ ] Exercise two sessions, repeated clicks, interruption/restart, failed sibling resources, review revisions, disk/write errors and backup/restore.
- [ ] Run acceptance scenarios for every RF08-RF16 criterion, and measure a declared file/row/size/concurrency envelope with representative ecological data.

**Gate:** All applicable RF08-RF16 scenarios pass; omissions are named rather than reported as complete. Saved runs remain inspectable after parser, policy, decision or reference changes. No PDF/HTML/Quarto reporting work is required for this release.

Suggested R verification commands once the package and tests exist: `devtools::test()` and `R CMD check .`; use `shiny::testServer()` for module logic and a browser-level acceptance run for the complete user workflow.

## Roadmap after validation

| Order | Requirements | Deliverable and gate |
|---|---|---|
| 7 | RF17-RF19, RF23 | Semantic proposals and adaptive DwC mapping, explicit approval queue, immutable derived versions and record/attribute lineage. Retain unmapped information and one-to-many mappings. |
| 8 | RF20-RF22, RF24 | Deterministic unit/taxon/value transformations, approvals for uncertainty, comparative pre/post QC. Critical issues or incomplete mandatory checks block integration; warnings alone do not. |
| 9 | RF25-RF31 | Eligible-input selection, explicit exclusions, integration, identifier remapping, duplicate/overlap and conflict decisions, attribute provenance and comparative QC. Preserve independent operations when a reconciliation is blocked. |
| 10 | RF32-RF33 | DwC-A/CSV data exports and EML metadata, version consistency, dependency-safe partial exports and explicit quality limitations. Blocked/not-assessed datasets may be exported with disclosure as required by RF32. Incomplete/non-compliant EML is never labelled valid. |
| 11 | RF34 | Versioned method catalogue and configurable ecological analyses, prerequisite checks and sampling-context limitations; retain results/configuration for future reporting. |
| Cross-cutting, staged | RF36 | First evidence-linked explanations, then structured proposals executed only by supported application services after approval. Revalidate stale proposals. No arbitrary AI code execution or autonomous edits. |
| Deferred | RF01-RF07, RF35 | Harvesting connectors and Quarto formatted reporting require separate future work. Structured processing evidence created now is their future input. |

AI assistance should not be required to run deterministic validation. Later phases with explicit AI requirements are not complete until their corresponding approval and traceability scenarios are verified. RF36 reporting/harvesting behaviours remain deferred with those stages.

## First development increment

The input/history foundation and Tasks 2A–2C are published, including clarification
and ordinary ZIP support. Task 2D is published in efe5916.
Task 2E (persisted runs and Shiny results) and its guided date workflow are implemented and approved for publication;
Task 2F integrated acceptance is next. After separately authorised follow-on work, demonstrate
upload -> declaration/mapping -> linkage/date recognition -> summary/details ->
restart/retrieve. Independent date processing survives linkage limitations.
This increment does not claim full RF08–RF16 or a complete review-decision workflow.

Before scheduling work, establish representative sizes, deployment/users and scientific policy owners. Use milestone gates rather than unsupported calendar estimates.

## Technical references checked for this proposal

- Shiny non-blocking operations: https://shiny.posit.co/r/articles/improve/nonblocking/
- SQLite WAL concurrency and same-host filesystem constraints: https://www.sqlite.org/wal.html
- ChecklistBank API implementation/documentation entry point: https://github.com/CatalogueOfLife/backend
- WoRMS supported services: https://www.marinespecies.org/aphia.php?p=webservice

## Proposal self-review

RF08-RF16 map to Tasks 2-6, with the shared foundation in Task 1. RF11 explicitly covers cross-dataset candidates; RF14 retains general validation on unknown schemas; RF15 includes both required reference sources; RF16 preserves independent results/decisions and optional review. RF17-RF34 and RF36 have subsequent roadmap positions. RF01-RF07 and RF35 remain deferred. The five review-focus classes have explicit test scenarios in their owning tasks. No scientific thresholds or timings absent from the specification are presented as agreed facts.


Publication approval (25 November 2026): the user approved committing and pushing
Step 2B, clarification workflow and ZIP support without meta.xml to martinaPulieri/ecodata.
Final combined verification: 772 assertions, zero failures/errors/warnings/skips; installed-package Status: OK.


Publication approval (25 November 2026): the user approved Step 2C code, tests,
updated plan and documentation for commit/push to martinaPulieri/ecodata.
Verified suite: 928 assertions with zero failures/errors/warnings/skips; installed-package Status: OK.
