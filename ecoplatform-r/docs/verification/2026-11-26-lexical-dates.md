# Task 2D — lexical date recognition

User authorised implementation, tests and documentation on 26 November 2026.
The user explicitly approved committing and pushing the implementation, tests
and updated documentation on 26 November 2026.
Base commit: 8133d8a. SQLite remains v2; no Shiny UI changes.

## Delivered behaviour

`run_date_validation()` executes TMP-00–03/TMP-08 against exact configured
tables. Supported patterns cover fixed-width numeric dates, partial dates,
literal-Z timestamps, explicit YMD intervals and named split components.
Original values, widths, headers, zero-based positions, roles, row locators and
catalogue/mapping provenance remain attached to typed records. Ambiguity is
preserved until supported by explicit order evidence or enabled-pattern policy.
Impossible calendar dates can be lexically recognised. No source conversion,
calendar validation, database result persistence or new Shiny controls are included.

Historical date-patterns-0.1 definitions/hashes and the default specification
behaviour remain unchanged. The executable 1.0 catalogue has the same initial
pattern definitions and can be selected explicitly. Effective descriptor contexts
carry verified meta.xml provenance alongside saved evidence.

## Executed verification

- Focused final date tests: **123 passed assertions; zero failures, errors,
  warnings or skips**. Includes lexical, integration, cancellation, provenance,
  rule coverage and catalogue-read scaling cases.
- Synthetic demonstration rerun after review fixes: **18 typed records**, with
  identical output after repository close/reopen, unchanged source/configuration
  hashes and zero configuration/operation writes by the engine.
- Full final source regression suite: **1,051 passed assertions; zero failures,
  errors, warnings or skips** (928 existing plus 123 new assertions).
- Final built/installed `R CMD check --no-manual`: **Status: OK**, including
  installed-package tests, namespace, dependencies, syntax and API help checks;
  no warnings or notes.
- `git diff --check`: clean. Verification was performed against the uncommitted
  Task 2D changes based on the commit identified above.

Environment: Windows, R 4.4.3, existing ECODATA_R_LIBRARY;
LANG=en_US.UTF-8, LC_ALL=English_United States.utf8. No new dependencies or live
reference services. Commands run from ecoplatform-r/:

```text
Rscript --vanilla -e 'pkgload::load_all("."); testthat::test_dir("tests/testthat", filter="^date-")'
Rscript --vanilla tools/test-step1.R
Rscript --vanilla tools/check-step1.R
Rscript --vanilla tools/manual-dates.R
```

When ECODATA_R_LIBRARY is set, prepend it to `.libPaths()` for direct `-e`
invocations; the three tools scripts do this themselves. Package-check evidence
is directed with ECODATA_CHECK_EVIDENCE to evidence/dates-package-final/.

## Synthetic expected and observed results

| Status | Single field (9 rows) | Split group (9 rows) |
|---|---:|---:|
| Recognised | 6 | 6 |
| Ambiguous | 1 | 0 |
| Unrecognised | 1 | 1 |
| Missing | 1 | 1 |
| Incomplete | 0 | 1 |
| Not evaluated | 0 | 0 |

The fixture includes 2020-02-30, undocumented 03/04/2020, partial dates, a
timestamp, interval endpoints, reordered anno/giorno/mese columns, leading zeros,
a missing component and all-empty components. Pattern counts include candidate
memberships; both candidates on an ambiguous row are intentionally counted.

## Independent review and corrections

A read-only independent reviewer reproduced five issues. Each has a failing-first
regression followed by the focused green run:

1. Unconfirmed saved suggestions suppressed a usable descriptor field. Only usable
   confirmed mappings now supersede descriptor evidence; suggestions remain unevaluated.
2. Per-row construction/summary validation repeatedly reloaded invariant catalogues.
   Internal row construction now reuses a validated mapping context; public APIs
   retain context validation, and summaries still verify every row's hash/payload.
   Catalogue reads are bounded independently of row count. A separate probe observed
   **14 catalogue reads at both 20 and 200 rows**, versus the review's 174 reads
   at 20 rows before the fix. Elapsed times during concurrent verification were
   9.67 and 26.77 seconds respectively; this is not workload qualification.
3. Early cancellation of a descriptor-targeted run raised an unknown-mapping error.
   Cancellation now preserves the requested selection without inventing a resolved
   mapping, row or population.
4. Saved descriptor mappings omitted actual descriptor provenance. Effective frozen
   mapping evidence now includes the verified descriptor member/digest/index while
   preserving the original saved declaration.
5. TMP-02 counted blank rows as pattern matches evaluated. Its coverage population
   now comprises nonmissing values, independently of whole-population TMP-01 screening.

Earlier boundary tests also corrected stale population claims after source changes
and ensured a one-shot cancellation request remains latched for the entire run.
No review findings were deferred. The reviewer did not duplicate the parent's full
suite/package checks or assess the separately scoped Task 2E interface/persistence.

## Evidence and remaining boundaries

Ignored local evidence includes date-review-green.txt, date-final-suite.txt,
date-final-manual.txt, dates/synthetic-result.json, dates/manual-result.json,
date-scaling.txt and dates-package-final/package-check.txt. Red-run logs are kept
alongside them for the boundary/review regressions.

The demonstration uses synthetic data only and makes no approvals or claims about
research datasets. No browser interaction was required: Shiny execution/results,
durable validation storage and integrated browser acceptance remain Tasks 2E/2F.
Natural language, two-digit years, variable-width single-field dates and unlisted
timestamp/timezone variants remain unsupported. Calendar validity, interval
ordering and broader RF10 scientific checks remain later work.
