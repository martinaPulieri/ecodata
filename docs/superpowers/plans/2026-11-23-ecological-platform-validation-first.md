# Ecological Data Platform: Validation-First Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this proposal task by task after design choices have been reviewed. Checkboxes track future work; none represents completed implementation.

**Goal:** Build an ecological data integration platform beginning with non-destructive data validation and persistent interactive review.

**Architecture:** A modular R application separates domain functions, application services, SQLite repositories and Shiny modules. Immutable source files and derived artefacts live in managed file storage; SQLite records identities, configurations, processing history, findings, evidence and review decisions.

**Tech stack:** R, Shiny, SQLite through DBI/RSQLite; Quarto reserved for a later reporting phase. Candidate supporting libraries: bslib, testthat, jsonlite, digest, xml2, units and sf, selected and locked during implementation.

**Spec:** Functional_Requirements_Structured_RF01_RF36.pdf, especially Data Validation RF08-RF16 (pages 11-13), downstream RF17-RF34 and outstanding definitions (page 34). The user's request excludes harvesting and reporting. Previous project plans are intentionally disregarded.

**Status:** Fresh proposal, not an assessment of existing implementation or an instruction to resume previous work. File names and interfaces below are proposed.

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

The recommendation is a proposal, not a previously approved architecture.

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
R/inputs/           registration, safe archives, parsing, metadata, schema profiles
R/validation/       registry, structure, identifiers, geography, time, measurements, duplicates, taxonomy
R/services/         submission, orchestration, review, eligibility
R/repositories/     SQLite migrations, runs, findings, decisions, references
R/shiny/            project, inputs, configuration, run, results, review, history modules
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

**Files:** inputs/registration.R, inputs/parsing.R, inputs/profiles.R; repositories/connection.R, migrations.R, runs.R; services/contracts.R; inst/sql/001_validation.sql; inst/profiles/*.json; corresponding test files.

**Interfaces:** produces register_input(), inspect_input(), confirm_profile() and the versioned input/result contracts consumed by Tasks 2-6.

- [ ] Define and version profiles, required-field rules, severities, applicability and state transitions.
- [ ] Implement managed immutable copies, hashes, file/table/record identities, safe ZIP inspection and reproducible parser settings.
- [ ] Implement migrations, immutable configuration revisions and traceable run submission; record supplied provenance gaps.
- [ ] Test clean and malformed files, encoding/delimiter overrides, empty input, unsupported formats, archive traversal/size bounds, duplicate filenames, restart and migration rollback.

**Gate:** Register and reopen inputs; reconstruct their exact bytes, parser settings and metadata without changing originals. No schema-specific rules execute without confirmation.

### Task 2: First working validation/review slice — RF08, RF12, RF14, RF16

**Files:** validation/registry.R, structure.R, identifiers.R; services/validation.R, review.R; repositories/findings.R, decisions.R; shiny/mod_inputs.R, mod_validation.R, mod_results.R, mod_review.R, mod_history.R; associated tests.

**Interfaces:** produces validate_dataset(), submit_validation(), query_findings(), save_review(); later checks return the same result contract.

- [ ] Implement required fields/types/formats and declared key/reference checks for the confirmed profile.
- [ ] Implement schema candidates, confirmation and unsupported-schema fallback to general checks.
- [ ] Add Shiny input configuration, explicit Run action, results filtering, record inspection, decisions and history.
- [ ] Test missing/duplicate IDs, unresolved references, valid parent/child relationships, unknown schemas, non-applicable checks, decision updates and stale-context rejection.
- [ ] Test a full register -> validate -> review -> restart -> retrieve sequence; assert unchanged input hash and preserved previous decisions.

**Gate:** A user can run a real structural assessment and review selected findings without reviewing everything. Distinguish counts of findings, affected records and evaluated records.

### Task 3: Geography and time — RF09, RF10

**Files:** validation/geography.R, temporal.R; versioned spatial reference manifests; dedicated fixtures/tests.

- [ ] Check coordinate lexical/numeric format, complete pairs, ranges and confirmed CRS prerequisites.
- [ ] Assess country/country-code and marine/terrestrial consistency using versioned reference layers; disclose coastline resolution/tolerance and uncertainty.
- [ ] Check real calendar dates, partial dates, intervals, cross-field consistency and declared metadata coverage.
- [ ] Test poles/dateline, zero coordinates, absent CRS, coastline ambiguity, leap days, ambiguous day/month conventions, partial-date intervals, timezones and out-of-coverage records.

**Gate:** Suspicious geography is explained; coordinates are not swapped or transformed in source data. Partial dates are not assigned invented precision; unresolved conventions remain explicit.

### Task 4: Measurements and duplicate candidates — RF13, RF11

**Files:** validation/measurements.R, duplicates.R; repositories/duplicate_groups.R; versioned variable constraints; fixtures/tests.

- [ ] Validate values, known units, dimensional compatibility and documented variable constraints; retain zeros, missing markers and censored expressions distinctly.
- [ ] Detect exact and potential duplicates within/across explicitly selected versions using source-scoped identifiers and documented attribute rules.
- [ ] Store duplicate groups, evidence and member links; use indexed blocking strategies rather than unbounded all-pairs comparison.
- [ ] Test missing/unknown/incompatible units, context-dependent quantities, below-detection values, exact duplicates, source-ID collisions and scientifically distinct repeat observations.

**Gate:** No unit conversion, deletion or merge occurs. Every duplicate candidate explains its evidence and scope. Unit compatibility alone does not establish comparability of sampling methods.

### Task 5: Taxonomic evidence — RF15

**Files:** validation/taxonomy.R; references/checklistbank.R, worms.R, cache.R; recorded-response fixtures and tests.

- [ ] Flag abbreviations, qualifiers such as cf./aff., and nomenclatural annotations without deleting their information.
- [ ] Implement separately tested ChecklistBank/Catalogue of Life and WoRMS TaxaMatch adapters; confirm current endpoints, authentication, quotas and match semantics during an initial capability probe.
- [ ] Deduplicate equivalent requests using name plus relevant authority/rank/classification context, reference release and matching parameters; do not collapse distinct ambiguous queries.
- [ ] Retain candidate matches, accepted/synonym status, conflicts, unmatched results and source-record links; cache query/response evidence with retrieval time and source version when available.
- [ ] Test accepted names, synonyms, ambiguous names, conflicting services, repeated requests, qualifiers, timeouts, rate limits and unavailable version metadata using recorded responses.

**Gate:** Repeated equivalent queries reuse evidence; service failures produce an incomplete assessment, not an unmatched taxon or a pass. Original identifications remain unchanged. A pinned cached-evidence run is reproducible; a live rerun may differ and must record new reference context.

### Task 6: Complete validation release — RF08-RF16

**Files:** services/orchestration.R, eligibility.R; repositories/query_indexes.R; Shiny progress/results/history modules; end-to-end fixtures and acceptance matrix.

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

Implement Tasks 1-2 as one small vertical slice, then extend the same contracts through Tasks 3-6. The first demonstration should load a generic ecological CSV and a small declared DwC-A, inspect/confirm their configuration, detect structural/relational issues, record a review decision, restart and recover the same evidence and history. This is a useful first milestone, not a claim of full RF08-RF16 coverage.

Before scheduling work, establish representative sizes, deployment/users and scientific policy owners. Use milestone gates rather than unsupported calendar estimates.

## Technical references checked for this proposal

- Shiny non-blocking operations: https://shiny.posit.co/r/articles/improve/nonblocking/
- SQLite WAL concurrency and same-host filesystem constraints: https://www.sqlite.org/wal.html
- ChecklistBank API implementation/documentation entry point: https://github.com/CatalogueOfLife/backend
- WoRMS supported services: https://www.marinespecies.org/aphia.php?p=webservice

## Proposal self-review

RF08-RF16 map to Tasks 2-6, with the shared foundation in Task 1. RF11 explicitly covers cross-dataset candidates; RF14 retains general validation on unknown schemas; RF15 includes both required reference sources; RF16 preserves independent results/decisions and optional review. RF17-RF34 and RF36 have subsequent roadmap positions. RF01-RF07 and RF35 remain deferred. The five review-focus classes have explicit test scenarios in their owning tasks. No scientific thresholds or timings absent from the specification are presented as agreed facts.
