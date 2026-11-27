# Approved date workflow implementation plan

**Publication approval (27 November 2026):** The user approved committing and
pushing the implementation, tests and documentation after reviewing results.
This supersedes the pre-approval working-state constraints and ledger below.

**Goal:** Implement the two-tab mockup approved on 27 November 2026.
**Spec:** `outputs/mockups/shiny-date-workflow.html` in the parent workspace and
the user's detailed request/approval in this chat.
**Architecture:** Keep the existing immutable repository and supervised validation
worker. Embed preview below reading configuration. A separate background information
worker reads tables; Shiny polls its actual stages and displays date declarations.
Persist selected column positions and catalogue formats, then run only dates.
**Execution:** Inline with executing-plans and test-driven development.

## Constraints

- Preserve the uncommitted Task 2E work; do not stage, commit or push.
- No Date role or Reason/evidence inputs in the new flow. System provenance records
  explicit field/format selection without inventing a scientific semantic role.
- Inference is a suggestion; ambiguous/mixed/empty fields need explicit selection.
- Exact declared format is checked, including separator/width; preserve source text.
- Keep historical mappings/results readable and existing non-date clarification APIs.
- Validation and Results screens remain available without redesign.

## Review focus

Stale context during a background check; preview lost on revision acknowledgement;
ambiguous and mixed formats; overrides ignored by validation; duplicate Run clicks.

## Tasks

- [x] Write failing tests for declared-pattern persistence/exact comparison,
  inference including ambiguity and multiple columns, and combined save/preview.
- [x] Extend the backwards-compatible mapping contract and date classifier;
  add date-information/declaration services with immutable revision guards.
- [x] Embed preview; combine save/preview; add Next. Implement a supervised
  information worker, bullet list of date fields/formats and dates-only Run action.
- [x] Run focused tests, full regression suite and installed-package check;
  independently review changes and verify the real browser workflow.
- [x] Update user/architecture/verification docs and show the app before commit.

## Ledger

Focused initial verification: 32 new workflow assertions plus existing Shiny tests
passed. Independent review identified deselected-field leakage and override loss
when adding fields; regressions reproduced both. Fixed explicit selected scope,
table replacement and per-field override retention; restored split defaults.
Additional cross-file regression reproduces stale draft input reuse. Final
context-scoping/launch-error corrections passed all 41 workflow assertions.
Final browser verification observed zero new client errors, actual dates-only
results at revision 8 (6 matching, 4 mismatching, 2 missing), and a 375px layout
without global horizontal overflow. The Run button is stable across revision/tab
changes; a Shiny dynamic-output state error was reproduced and resolved. Final
comprehensive verification passed against frozen R source: 1,208 assertions,
zero failures/errors/warnings/skips. Installed-package build/check: Status OK,
no warnings or notes. Documentation and screenshots are complete; the running
app at http://127.0.0.1:8800 is ready for user review. Nothing is staged,
committed or pushed.

Ruling: use the existing catalogue's supported formats, including split components,
and disclose unsupported formats rather than accepting a format we cannot check.
Ruling: use a neutral technical role internally for new UI mappings to preserve
historical contracts; no semantic meaning is inferred or asked of the user.
Ruling: inference may use numeric month/day plausibility to distinguish DMY/MDY;
validation remains lexical and does not certify calendar dates.
