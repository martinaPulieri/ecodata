# Timestamp inference and Validation progress — 27 November 2026

## Reported problem and cause

The supplied `9dc22d78-c41c-43ac-ba09-647e5c75f0a8.csv` contains 42 data rows.
Every DATA PRELIEVO value has the exact shape `2009-06-29T00:00:00`: a date and
time without a timezone suffix. YYYY-MM-DD excludes the time; the previous
timestamp pattern requires a literal trailing Z. Neither matched, and inference
uses the same exact catalogue definitions, so it could not suggest either format.

## Change

Catalogue **date-patterns-1.1** adds a separate **timestamp-no-zone** pattern,
displayed as **YYYY-MM-DDTHH:mm:ss**, with timezone explicitly unspecified.
Historical 0.1/1.0 catalogues and saved results are unchanged. The guided flow
uses 1.1 for inference and new declarations; the executing engine reports 1.1.
Z timestamps retain their distinct pattern. No timezone, UTC conversion, trimming
or date correction is invented. Offset/fractional-second variants remain unsupported.

Detected format is now named explicitly beside the selector. A different saved
choice is preserved until the operator selects the detected format and runs again.
The Validation tab displays an accessible indeterminate activity bar for queued
or running jobs with actual persisted stage messages. There is no fabricated
percentage/remaining time. Terminal runs have no activity bar.

## Evidence

- Failing-first tests reproduced missing inference, rejected declarations and the
  missing activity component. Focused date/workflow/Shiny regressions then passed.
- New coverage includes no-zone versus Z timestamps, mixed columns, rejected
  timezone offsets, preserved whitespace, old catalogue compatibility, declared
  pattern/catalogue consistency and queued/running/cancelled/terminal UI states.
- `tools/manual-timestamp-progress.R` used a fresh local runtime and a registered
  copy of the supplied CSV. A real background worker recognised **42/42**, with
  zero unrecognised/missing/ambiguous records. Original file SHA-256 was unchanged;
  saved payload was identical after repository restart.
- Actual Shiny workflow on the user's already registered dataset: revision 7
  saved the preview, Missing information displayed detected YYYY-MM-DDTHH:mm:ss
  beside the older saved YYYY-MM-DD choice. Selecting the correct pattern and Run
  created revision **8** and a dates-only assessment with **42 recognised** and
  zero in every other date classification. Previous revisions/results remain.
- Browser observed queued/running Validation progress, then zero progress bars
  after completion. Browser console error log was empty. App remains open on the
  successful saved Results at http://127.0.0.1:8800/ using its existing runtime.
- Independent focused review found no blocking issue. The engine-version label
  noted by review was aligned to 1.1 before final checks.

Final complete regression suite: **1,235 passed assertions**, zero failures,
errors, warnings or skips (27 additional assertions beyond the approved flow's
1,208). Installed-package build/check: **Status: OK**, no warnings or notes.
`git diff --check` passed. Results were presented before staging.

Ignored evidence: `evidence/timestamp-progress-red.txt`,
`timestamp-progress-focused.txt`, `timestamp-progress-suite.txt`,
`timestamp-progress-package/package-check.txt`, `timestamp-progress-manual.txt`,
and `timestamp-progress/manual-result.json`. Screenshots: inferred-format.jpg,
validation-progress.jpg and results-42.jpg in `evidence/timestamp-progress/`.

Environment: Windows, R 4.4.3, existing ECODATA_R_LIBRARY, LANG=en_US.UTF-8,
LC_ALL=English_United States.utf8. Commands: tools/test-step1.R,
tools/check-step1.R and tools/manual-timestamp-progress.R (ECODATA_DATE_INPUT
explicitly names the supplied file; an existing acceptance runtime is refused).

No dependencies/schema migration in this follow-on fix. The user approved committing
and pushing the implementation, tests and updated documentation on 27 November 2026.
Recognition concerns declared lexical shape, not calendar validity.
