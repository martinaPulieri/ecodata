# Timestamp recognition and validation activity

**Publication approval (27 November 2026):** The user approved committing and
pushing the implementation, tests and documentation after reviewing results.
This supersedes the pre-approval working-state notes below.

User request: add a Validation progress bar and diagnose failed date recognition
for data_examples/9dc22d78-c41c-43ac-ba09-647e5c75f0a8.csv. Build on the uncommitted
approved workflow; no commit/push before review.

Diagnosis: all 42 DATA PRELIEVO values are YYYY-MM-DDTHH:mm:ss, with no timezone.
The 1.0 catalogue offers a date-only pattern and a timestamp requiring literal Z;
neither matches. Inference intentionally uses those same exact definitions.

- [x] Reproduce with failing inference, exact-match and pending/terminal progress tests.
- [x] Add immutable catalogue 1.1, retaining 0.1/1.0 unchanged. Add a separate
  timestamp-no-zone pattern; keep timezone unspecified and never append Z.
- [x] Use 1.1 in guided declarations/inference; display indeterminate validation
  activity for queued/running work with actual saved stage messages.
- [x] Test the supplied CSV read-only and a synthetic counterpart, run full suite
  and package check, verify browser, update docs and show results uncommitted.

Ruling: unknown-duration activity is indeterminate, without a fabricated percentage.
Ruling: timestamp offsets/fractions remain unsupported rather than being conflated
with timezone-free or UTC timestamps. Calendar validation remains out of scope.

Ledger: all 42 supplied timestamps recognised in both an isolated real-worker test
and the existing Shiny workspace (new revision 8); originals unchanged, prior
results retained. Browser activity bar observed while queued/running, absent after
completion; no console errors. Focused review clean; engine version aligned to1.1.
Full suite: 1,235 passed, zero failures/errors/warnings/skips. Package build/check:
Status OK, no warnings or notes. Documentation and screenshots updated. No staging,
commit or push; ready for user review.
