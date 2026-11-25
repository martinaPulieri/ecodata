# Task 2A — versioned rules, mappings and result contracts

Verification completed on 25 November 2026. The user reviewed the results and
explicitly approved committing and pushing the updated plan, code, tests and
documentation for Task 2A to martinaPulieri/ecodata.

## Delivered scope

- Updated the approved validation-first plan: completed foundation recorded,
  Task 2 split into 2A–2F, lexical date recognition brought forward and scientific
  calendar/range/EML checks explicitly deferred. Flat R package layout retained.
- Fourteen versioned rule definitions (PRE-01, LNK-01–08, TMP-00–03, TMP-08).
- Ten provisional date-pattern definitions, with no matcher or calendar validation.
- Source/version/resource/table-scoped date and descriptor linkage declarations,
  zero-based column positions, original headers, roles, evidence and confirmation.
- Complete catalogue snapshots/digests and mapping specifications stored in
  append-only configuration JSON. Ordinary parser/profile edits inherit them;
  prior payload integrity is checked before inheritance. Legacy rows stay unchanged.
- Frozen contexts and typed check/date/linkage/finding records, including original
  text, row locators, candidate patterns/targets, missing components and provenance.
- Mutually exclusive per-mapping summaries that reject missing/duplicate rows,
  altered records and contradictory imported source/configuration/table identities.

SQLite remains schema v2. There is no new full-table reader, scientific validator,
validation operation, results migration, UI, review-decision engine or reporting.
Table declarations are structurally checked but do not certify actual source
headers or descriptor usability; that prerequisite belongs to Task 2B.

## Executed verification

| Check | Observed result |
|---|---|
| Final full test suite | 463 passed assertions; 0 failures, errors, warnings or skips |
| Build and installed R CMD check --no-manual | Status: OK; no warnings or notes |
| Rule/version compatibility | All 14 definitions present; both canonical catalogue digests pinned |
| Mapping contracts | Column index 0, duplicate headers, reordered split components, distinct roles and explicit evidence retained |
| Configuration history | Append, inheritance, old snapshots, restart, stale/removed guards and corrupted-parent rejection verified |
| Portable records | Strict enums, mandatory context fields, positional array alignment, typed imported-record reconstruction and exact row bounds verified |
| Summary contracts | Zero populations, missing/duplicate rows, candidates and foreign source contexts tested |
| Manual synthetic demonstration | Exact expected contract counts; unchanged hashes; identical context after reopen; zero operations created |
| Existing behaviour | Registration, parser detection, Shiny module, removal, SQLite history and concurrency regressions remain green |

The final suite contains the original 335 assertions plus 128 assertions covering
this slice. R help pages were regenerated from documented exported functions.

## Demonstration results — supplied examples, not detected findings

The script supplies synthetic outcomes to the constructors, then independently
asserts the aggregate counts and restart/integrity properties. It does not derive
these classifications by inspecting the data.

| Example | Expected and observed contract counts |
|---|---|
| Three split-date rows | 1 recognised, 1 incomplete (missing month), 1 missing |
| Separate 03/04/2020 analysis-date record | Ambiguous; DMY and MDY candidates retained |
| Five measurement rows | 2 linked, 1 ambiguous, 1 unresolved, 1 missing reference |
| Ambiguous linkage | Two core candidates retained; measurement row counted once |
| Reopen and file integrity | Frozen context identical; all source hashes unchanged |

The persistent synthetic runtime is
`C:/Users/tina_/AppData/Local/ecodata/validation-contracts-review-20261125-final`.
The generated JSON for inspection is `evidence/validation-contracts/manual-result.json`.
The archive Occurrence_Measures_Example1.zip and its 8,480/2,916 reference inventory
were not evaluated; no real linkage/date findings are claimed.

## Review and decisions

An independent read-only review found no Critical issues and identified structural
contract weaknesses. Regression tests reproduced them before one fix pass:
explicit enums, confirmed linkage targets/cardinality, portable context structure,
foreign/resealed row identities, named positional array alignment, prior-payload
integrity, lossless integer bounds and immutable catalogue compatibility hashes.
All final tests and the installed-package check passed after those fixes. The
reviewer did not perform a second review of the fixed tree; the implementer
verified the fixes with tests and the demonstration.

- Existing feature checkout retained; no extra branch/worktree was created.
- Mappings are declarations only; full source certification is outside Task 2A.
- Existing JSON snapshots avoid an unnecessary schema migration; result tables
  remain future work.
- Counts/positions are capped at 2,147,483,647 for exact JSON/R identity. Larger
  populations need a future lossless contract version; this is not a production
  workload qualification.
- Catalogue digests are canonical JSON SHA-256 compatibility checks, not signed
  authentication. Future versions must retain old catalogue definitions.
- Execution performance, full-table processing, scientific interpretation,
  results persistence and validation UI remain Tasks 2B–2F. No contract findings
  are deferred from this review.

Local logs are under ignored evidence/: contracts-final-tests.txt,
contracts-manual-final.txt, contracts-final-package.txt and
validation-contracts/final-package/. Synthetic files, databases and generated
results are not part of source publication. No dependencies were installed.

See [architecture](../architecture/validation-contracts.md) and
[repeatable manual checks](../user-guide/validation-contracts.md).
