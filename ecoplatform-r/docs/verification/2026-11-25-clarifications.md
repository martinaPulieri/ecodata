# Missing-information clarification workflow — verification

Implemented and verified on 25 November 2026. The user explicitly approved
commit and push of Step 2B, this workflow and ordinary ZIP support.

## Results

| Check | Observed result |
|---|---|
| Full regression suite | 662 passed assertions; 0 failures, errors, warnings or skips |
| New clarification cases | 105 assertions (90 service/domain and 15 Shiny), beyond the Step 2B baseline of 557 |
| Built and installed R CMD check --no-manual | Status: OK; no warnings or notes |
| Real Venezia input | 468 rows x 235 columns; 2 date questions pending; 0 approved answers; configuration remains revision 1 |
| Synthetic known date roles | Review writes 0; approval=FALSE rejected with 0 writes; explicit approval creates revision 2 |
| Independent date field | Still pending after the split sampling-date role is approved |
| Restart | Exact saved approval receipt retained after repository reopen |
| Original data and history | Source hashes unchanged; zero scientific rows evaluated; zero preparation/clarification operations |
| Shiny server integration | Suggestion/draft, cancel, approve exact reviewed values, history, changed operator and changed context exercised against real SQLite |
| Live application | Started on http://127.0.0.1:8795 using isolated local acceptance runtime |
| Visual browser inspection | Not completed: both browser and native UI automation kernels failed to start with Windows sandbox CreateProcessWithLogonW error 1920 |

## Delivered behaviour

The new Informazioni mancanti tab derives requests from exact complete-table
preparation, explains dependencies and offers editable unapproved suggestions.
A separate review modal displays exact values, evidence/operator and any mapping
replacements. Only Approva e salva nuova revisione saves an answer.
Cancel, field edits, selecting a suggestion and merely reading questions save nothing.

Approved parser/date/missing-key answers affect their corresponding prerequisites.
Answers are stored as clarification-answer-1.0 receipts in append-only
configuration JSON. Each receipt retains question/config/source scope, supplied
and applied values, evidence, operator and approval time. SQLite stays v2.
Previous revisions remain intact; unrelated valid mappings/settings are retained.

Ambiguous/invalid/out-of-range declared keys require source repair, rather than
an unsatisfiable mapping form or invented key. A supplied key is allowed only
where the key declaration is absent. Source-repair notes stay awaiting_source
and cannot certify readability, applicability or scientific validity.

## Independent review and regression fixes

One fresh read-only reviewer reproduced six material issues. A single fix pass
added regression tests and corrected:
1. Missing-vs-contradictory descriptor key handling and accurate source-repair routing.
2. Atomic parser-evidence inheritance so unrelated edits cannot erase pending review.
3. Independent unsaved date candidates after another field has been approved.
4. Explicit reviewed replacement of competing mappings for one archive relationship.
5. Explicit reviewed retirement of conflicting old schemas, preserving historical
   definitions and re-requesting uncovered fields against current headers.
6. Integrity failures permit source-repair notes only, never parser/mapping approval.

The independent-date issue was also discovered during manual acceptance and
its regression failed before correction. Mapping replacement IDs/reasons appear
in the reviewed draft and approval receipt. The final complete suite passed
after all fixes. No second review is claimed.

## Reproducible evidence

- tools/manual-clarifications.R: real questions plus synthetic approval.
- evidence/clarifications/manual-result.json: technical result summary and
  synthetic receipt; excluded from Git.
- evidence/clarifications-regression.txt: full suite summary.
- evidence/clarifications-package/package-check.txt: installed package check.
- tests/testthat/test-clarifications.R and test-shiny-clarifications.R.
- docs/user-guide/clarifications.md: operator workflow and manual checklist.
- docs/architecture/clarifications.md: API contracts, guards and provenance.

The isolated persistent runtime is
C:/Users/tina_/AppData/Local/ecodata/clarifications-review-20261125-final.
The real Venezia semantic questions remain unanswered. Synthetic operator
approvals are test data and do not assert ecological meaning for research files.

## Limits

This increment prepares information, not scientific results. Linkage matching,
date recognition, results persistence and background orchestration are still
later increments. Reading is synchronous and bounded by the Step 2B quotas.
The running UI is available for manual visual inspection; no screenshot or
completed end-to-end browser interaction is claimed.


Publication approval (25 November 2026): the user approved committing and pushing
Step 2B, clarification workflow and ZIP support without meta.xml to martinaPulieri/ecodata.
Final combined verification: 772 assertions, zero failures/errors/warnings/skips; installed-package Status: OK.
