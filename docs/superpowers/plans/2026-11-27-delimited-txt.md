# Standalone delimited TXT reading

The supplied Groundwater_Copepod_Trait_error.txt is a comma-delimited table,
but standalone detector/preview/full-reader/UI/clarification gates accept only
CSV/TSV. ZIP members already support TXT. Date edits do not cause this warning.

- [x] Reproduce missing TXT detection/preview/full-table support with tests.
- [x] Share one CSV/TSV/TXT predicate across standalone consumers; expose Detect
  format for legacy TXT registrations. Retain strict encoding/separator evidence.
- [x] Test real supplied file, full suite and installed package, verify Shiny and
  update docs; leave changes uncommitted for review.

Scope: lexical date-format checking only. 2025-19-02 matches YYYY-MM-DD shape;
calendar validity is not implemented. Trailing whitespace remains a mismatch.
No source renaming, trimming, date correction or century/timezone inference.

Results: 1,270 assertions passed with zero failures/errors/warnings/skips;
installed-package check Status: OK. Real supplied-file and Shiny runs both
reported 313 lexical matches and one trailing-space mismatch. Source integrity
and saved-result reopening passed. Independent review found no actionable issues.
See ecoplatform-r/docs/verification/2026-11-27-delimited-txt.md.
