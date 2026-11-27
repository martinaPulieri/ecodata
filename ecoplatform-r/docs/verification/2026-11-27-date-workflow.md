# Approved date workflow verification — 27 November 2026

User approved the interactive mockup and authorised implementation, tests and
documentation, with results shown before committing. Changes build on Task 2E
over efe5916. The user approved committing and pushing the complete implementation,
tests and updated documentation on 27 November 2026.

## Implemented behaviour

- Registration selects Data and configuration; reading controls appear immediately.
- Save and generate preview creates one revision and generates its exact preview,
  embedded below reading configuration. Browser revision acknowledgement retains it.
- Next opens Missing information and starts a supervised background information
  process with an indeterminate progress bar. The tab scrolls into view.
- Required information is a bullet list. Date columns have inferred, editable
  catalogue formats. Ambiguous/mixed/empty values require a format choice unless
  an exact declaration was already saved. Separate components are supported.
- Date role and Reason/evidence inputs are removed from this flow. Neutral technical
  provenance is recorded automatically; no original value is changed.
- Run validation saves the selected declarations and runs dates only, comparing
  each original value to its exact declared pattern. Selected scope excludes
  deselected columns and additional descriptor/suggested dates.
- Existing Validation/Results layouts remain. Historical unrestricted mappings
  retain their previous recognition behaviour and saved results remain immutable.

## Automated evidence

The first comprehensive implementation run passed **1,203 assertions**, zero
failures/errors/warnings/skips, and installed-package check finished **Status: OK**.
Additional context/launch tests bring the focused workflow set to **41 assertions**,
all passing. Final comprehensive verification after the browser-transition
correction: **1,208 passed assertions**, zero failures, errors, warnings or skips.
The installed-package build/check finished with **Status: OK**, no warnings or notes.

Independent review found deselected-field leakage, overridden formats resetting
when adding a column, and saved split defaults not being restored. These were
corrected. Further regression tests caught cross-file reuse of input values and
worker startup failures leaving perpetual progress. Per-check format input IDs
isolate draft state, and startup failures leave a retryable error.

A browser run exposed a Shiny client output-state error during revision changes.
The Run button now has a stable DOM element with context-bound readiness messages,
avoiding dynamic output destruction during the transition. The final browser run
saved revision 8 and its 12 row classifications with **zero new client errors**.
The app is left at Missing information with revision 9's preview/preparation ready
for user review. Both final source/package checks completed successfully against
unchanged R source; `git diff --check` also passed.

One intermediate source run had two failures in the source-change publication
test because R files were edited while fingerprint-protected jobs were executing.
The final verification freezes R source throughout both runs; intermediate logs
are retained and are not treated as passing evidence.

## Synthetic results

`tools/manual-date-workflow.R` creates an isolated synthetic CSV and a new local
runtime. Six rows contain two independently declared date columns.

| Declaration | Matching | Mismatching | Missing |
|---|---:|---:|---:|
| date_observed = DD/MM/YYYY; date_processed = YYYY-MM-DD | 8 | 2 | 2 |
| Browser override: both columns = YYYY-MM-DD | 6 | 4 | 2 |

The original hash remained unchanged, and the complete saved payload was identical
after closing/reopening the repository. No linkage family ran. The impossible
calendar date 30/02/2020 matches a DMY lexical declaration; it is not calendar-validity
evidence. Whitespace is preserved and produces a fixed-format mismatch.

## Browser and retained evidence

The isolated app is at http://127.0.0.1:8800 using
`C:/Users/tina_/AppData/Local/ecodata/date-workflow-review-20261127-final`.
Earlier runtimes and original research inputs are preserved.

Observed: merged save/preview, exact revision retained, Next automatic check and
visible progress bar, bullet/field controls with no role/evidence input, editable
format and a genuine dates-only Run. Results display the expected override counts
and all 12 original values. A narrow layout measured 375px client/scroll width,
with no global horizontal overflow. Temporary viewport overrides are reset.

Ignored evidence under `evidence/` includes date-workflow-focused.txt,
date-workflow-review-red.txt, date-workflow-context-red.txt,
date-workflow-context-green.txt, date-workflow-verified-suite.txt,
date-workflow-package-verified/package-check.txt, date-workflow-release-manual.txt,
and date-workflow/manual-result.json. Screenshots include config-preview-final.jpg,
information-progress-final.jpg, missing-information-final.jpg, results-final.jpg
and missing-information-mobile.jpg. `date-workflow/browser-final.json` records
375px client/scroll width and zero new errors after the final reload;
`date-workflow/final-live-result.json` retains the final browser-run summary.

Commands: `Rscript --vanilla tools/test-step1.R`,
`Rscript --vanilla tools/check-step1.R`, `Rscript --vanilla tools/manual-date-workflow.R`.
Environment: Windows, R 4.4.3, existing ECODATA_R_LIBRARY, LANG=en_US.UTF-8,
LC_ALL=English_United States.utf8. No new dependencies or schema migration.

## Limits

Formats are limited to the versioned catalogue. Inference is a suggestion and
can use month-position plausibility; validation remains lexical. No calendar
certification, conversion or harmonisation is performed. Full-reader and output
quotas remain disclosed. Task 2F production workload qualification is separate.
