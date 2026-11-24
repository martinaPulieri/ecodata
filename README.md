# Ecological Data Integration Platform

An R application for inspecting, validating, reviewing and eventually integrating heterogeneous ecological datasets.

The approved technology choices are **Shiny** for the interface, **SQLite** for processing history and review decisions, and **Quarto** for future formatted reports. Development starts with **Data Validation, RF08-RF16**. Harvesting and formatted reporting are deferred.

Source repository: [martinaPulieri/ecodata](https://github.com/martinaPulieri/ecodata).

## Current status

The approved first implementation now includes immutable input registration, versioned parser configurations, SQLite processing history, a local Shiny interface and automatic encoding/separator detection. Scientific validation rules, finding review, harvesting and formatted reporting remain later work. The structure below is the agreed roadmap; not every future module is implemented yet.

Start with the [application README](ecoplatform-r/README.md), [Shiny manual checks](ecoplatform-r/docs/user-guide/shiny-workspace.md) and [verified release scope](ecoplatform-r/docs/verification/2026-11-24-foundation-shiny-detection.md).

The approved plan is [Ecological Data Platform: Validation-First Implementation Plan](docs/superpowers/plans/2026-11-23-ecological-platform-validation-first.md). Earlier plans are not the basis for this implementation.

## Workspace structure

```text
PHD_IMPLEMENTATION/
|-- README.md
|-- Functional_Requirements_Structured_RF01_RF36.pdf
|-- data_examples/
|-- docs/
|   `-- superpowers/plans/
`-- ecoplatform-r/
    |-- DESCRIPTION
    |-- NAMESPACE
    |-- README.md
    |-- app.R
    |-- renv.lock
    |-- R/
    |-- inst/
    |   |-- sql/
    |   |-- profiles/
    |   |-- rules/
    |   |-- reference-manifests/
    |   `-- www/
    |-- tests/
    |   |-- testthat.R
    |   |-- testthat/
    |   |-- fixtures/
    |   |   |-- tabular/
    |   |   |-- dwca/
    |   |   |-- reference-responses/
    |   |   `-- expected-results/
    |   `-- acceptance/
    |-- docs/
    |   |-- architecture/
    |   |-- requirements/
    |   |-- decisions/
    |   `-- user-guide/
    |-- tools/
    `-- evidence/
```

### Workspace-level files

- `Functional_Requirements_Structured_RF01_RF36.pdf`: source functional requirements and verification criteria.
- `data_examples/`: original reference datasets. Preserve these files unchanged. Do not commit private, restricted or unlicensed source data without checking publication rights.
- `docs/superpowers/plans/`: approved implementation plans and milestone definitions.
- `ecoplatform-r/`: application and R package source. Its future README will contain application-specific setup, launch and troubleshooting instructions.

The workspace layout does not determine which existing files should be published. Before the first repository commit, inspect the remote layout and selectively stage the approved documentation/source files; never import the entire workspace automatically.

### Application entry points and dependencies

- `DESCRIPTION`: package identity, supported R version and declared dependencies.
- `NAMESPACE`: package exports/imports, generated from source documentation rather than edited independently.
- `app.R`: a small Shiny launch entry point; scientific logic belongs in package functions.
- `renv.lock`: dependency versions for a reproducible development environment.

### R source organisation

Keep source files directly inside `R/`. Standard R package loading does not recursively load nested source directories, so responsibilities are expressed using filename prefixes.

| Files or prefix | Responsibility |
|---|---|
| `app_ui.R`, `app_server.R` | Assemble the interface and connect modules to application services. |
| `input_registration.R` | Register immutable source copies and resource identities. |
| `input_parsing.R` | Parse reproducible views with explicit encoding, delimiter and numeric settings. |
| `input_archive.R` | Inspect archives safely and preserve their declared structure. |
| `input_profiles.R` | Manage schema evidence, confirmation and validation profiles. |
| `validation_registry.R` | Register rules, versions, prerequisites and applicability. |
| `validation_structure.R` | Required fields, data types and formats: RF08. |
| `validation_identifiers.R` | Identifier and declared relationship checks: RF12. |
| `validation_geography.R` | Coordinate and geographical consistency checks: RF09. |
| `validation_temporal.R` | Date, interval and temporal coverage checks: RF10. |
| `validation_measurements.R` | Measurement values, units and documented constraints: RF13. |
| `validation_duplicates.R` | Exact and potential duplicate candidates: RF11. |
| `validation_taxonomy.R` | Taxonomic expressions, consistency and match assessment: RF15. |
| `reference_checklistbank.R`, `reference_worms.R` | External taxonomic service adapters. |
| `reference_cache.R` | Preserve reusable reference queries, responses and retrieval context. |
| `repository_connection.R`, `repository_migrations.R` | SQLite connections, transactions and schema upgrades. |
| `repository_inputs.R`, `repository_runs.R` | Input versions, configuration snapshots and execution history. |
| `repository_findings.R`, `repository_decisions.R` | Validation evidence and separate review decision histories. |
| `service_validation.R` | Coordinate immutable inputs, rules, execution and result persistence. |
| `service_review.R` | Validate and record explicit review actions. |
| `service_eligibility.R` | Calculate policy-based readiness for a named downstream stage. |
| `mod_inputs.R`, `mod_configuration.R` | Shiny input selection, inspection and configuration. |
| `mod_validation.R`, `mod_results.R` | Explicit execution, progress, summaries and record inspection. |
| `mod_review.R`, `mod_history.R` | Selective review and retrieval of previous runs and decisions: RF16. |

Domain validation functions must be usable without Shiny or database writes. Shiny modules call application services; repositories own persistence. External service clients remain separate from scientific assessment rules.

### Installed resources: inst/

- `sql/`: numbered SQLite migrations. Document compatibility, backup requirements and rollback behaviour.
- `profiles/`: versioned generic and confirmed schema profiles, including required/recommended fields.
- `rules/`: configurable severity policies, scientific constraints and recognition rules.
- `reference-manifests/`: reference sources, versions, licences, retrieval information and hashes. Large reference datasets belong in managed runtime storage.
- `www/`: stylesheets, icons and other static assets; serve them through the Shiny resource mechanism configured by the application.

### Tests and verification

- `tests/testthat/`: focused tests for validation, repositories, services and Shiny module logic.
- `tests/fixtures/tabular/` and `dwca/`: small synthetic inputs with independently specified expected behaviour.
- `tests/fixtures/reference-responses/`: recorded service responses for deterministic taxonomy tests without live network dependencies.
- `tests/fixtures/expected-results/`: expected findings, counts, statuses and provenance references.
- `tests/acceptance/`: complete user workflows, including restart, interruption and manual inspection scenarios.
- `tools/`: repeatable development and verification scripts. Each script documents its prerequisites and effects.
- `evidence/`: generated verification logs, screenshots and runtime diagnostics, kept local and excluded from Git. Publish portable check summaries under `docs/verification/`; never commit private records, credentials or live databases.

### Technical and user documentation

- `docs/architecture/`: component boundaries, data contracts, database model and state transitions.
- `docs/requirements/`: traceability from each RF and verification criterion to implementation, tests and any outstanding limitations.
- `docs/decisions/`: dated technical/scientific decisions, their evidence, alternatives and consequences.
- `docs/user-guide/`: input preparation, configuration, execution, results interpretation and review instructions.

## Runtime storage

Keep operational data outside the Dropbox-synchronised workspace, using a configurable local application-data directory:

```text
<local application data>/ecoplatform/
|-- database/          # Active SQLite database
|-- inputs/            # Immutable registered source files
|-- artefacts/         # Versioned processing outputs
|-- reference-cache/   # External reference evidence
|-- logs/
|-- backups/
`-- tmp/
```

The application must document the resolved paths and their configuration. Never commit this runtime tree. Backups must use a consistent SQLite backup/snapshot procedure; do not copy an actively changing database as an informal backup. Approved backup snapshots may be copied to the backup destination separately.

Original source files, versioned results and recorded decisions are persistent records. Only temporary files may be removed as routine cleanup. Define retention separately before deleting persistent data.

## Scientific and processing rules

1. Validation identifies and explains issues without changing original scientific values.
2. Schema-specific checks require a confirmed supported schema. Unknown schemas retain applicable general checks.
3. Missing CRS, units, sampling context or other prerequisites must be disclosed rather than invented.
4. Duplicate detection produces candidates and evidence; it does not merge or delete records.
5. Taxonomic validation preserves original identifications and distinguishes unmatched names, ambiguous matches and service failures.
6. Keep applicability, execution state, findings, review state and downstream eligibility separate.
7. Store validation results and review decisions separately, preserving revision history and provenance.
8. Selective review is allowed: reviewing every finding is not a prerequisite for harmonisation.
9. Bind every run to exact input versions, parser/configuration revisions, rule versions and reference evidence.
10. Harvesting and formatted reporting remain deferred. RF16 structured validation results and interactive review remain in scope.

## Code documentation and manual inspection

Every approved implementation step must be understandable to a person inspecting the code and reproducible through documented checks.

- Use descriptive function names and focused files. Avoid mixing scientific policy, UI behaviour and SQL access in one function.
- Document exported functions with roxygen2: purpose, parameters, return structure, side effects, error behaviour and examples where useful.
- Document internal functions when their contract, assumptions or scientific interpretation is not evident from their names.
- Cite the applicable RF, rule/profile identifier and scientific reference where relevant. Explain the reason for non-obvious logic rather than restating the code.
- Make thresholds, tolerances, date conventions, matching policies and prerequisites explicit and versioned. Never hide scientific decisions in unexplained constants.
- Document database tables, keys, relationships, migrations and decision-history semantics.
- Include small, non-sensitive examples that let a reviewer compare inputs with expected findings.
- For each milestone, provide manual check steps: prerequisites, exact input fixture, launch/run action, expected visible result, expected persisted record and known limitations.
- Record verification commands and actual outcomes. Identify skipped checks and unavailable services explicitly.
- Keep the requirements traceability matrix and user guide aligned with the implemented behaviour.

## Approval, Git and GitHub workflow

The user has approved the implementation plan and this folder structure. Individual implementation steps still require the user's approval before execution.

For **every approved implementation step**:

1. Identify the approved scope, affected requirements and expected acceptance evidence.
2. Implement that scope with the code documentation described above.
3. Run relevant automated checks and document reproducible manual checks.
4. Inspect the diff and stage only files belonging to that step. Exclude credentials, runtime data, private datasets and unrelated workspace changes.
5. Create a focused Git commit with a descriptive message and relevant RF identifiers.
6. Push the approved step's commit to [martinaPulieri/ecodata](https://github.com/martinaPulieri/ecodata), following any repository branch/PR rules. Preserve existing remote history; do not force-push.
7. Report the commit hash/link, verification outcome and remaining limitations to the user.

Committing locally alone does not satisfy delivery to GitHub. If authentication, connectivity, permissions or branch protection prevents a push, preserve the completed work and state the exact blocker; never claim the repository was updated without confirmation.

Before the first commit, establish the local checkout from the existing remote and inspect its README, AGENTS.md and contribution guidance. Do not initialise an unrelated history or overwrite remote content. The repository's existing layout must be inspected before deciding how this workspace maps into the checkout.

## Initial implementation order

1. Input registration, versioned configuration and SQLite history foundation.
2. Structural/schema/relational validation with persistent interactive review.
3. Geographical and temporal validation.
4. Measurement validation and duplicate candidate detection.
5. Taxonomic validation and preserved external evidence.
6. Complete RF08-RF16 acceptance, recovery and workload qualification.

The first demonstration should load a generic ecological CSV and a small declared DwC-A, inspect and confirm configuration, detect structural/relational issues, save a review decision, restart and retrieve the same history. This demonstrates the first increment, not full validation coverage.
