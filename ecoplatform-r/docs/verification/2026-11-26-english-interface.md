# English interface verification — 26 November 2026

## Change

Translated the Shiny workspace into English: navigation, upload defaults,
parser controls, detection summaries, empty states, notifications, context
errors, preview/history headings, clarification forms and approval summaries,
and reversible removal/restoration dialogs. The page declares lang="en".

Updated the user guide, existing workflow test assertions and current operator
instructions to use the English control names. Approval-summary JSON labels are
display text only; persisted answer/configuration contracts are unchanged.
Source bytes, filenames, headers, user-provided text and historical records are
not rewritten. SQLite schema remains version 2.

## Verification performed

- Full source regression suite: **928 passed; 0 failed, errors, warnings or
  skipped assertions**. Command: Rscript --vanilla tools/test-step1.R.
  Environment: ECODATA_R_LIBRARY points to the existing development library;
  LANG=en_US.UTF-8, LC_ALL=English_United States.utf8.
- Existing Shiny module tests exercise registration, explicit parser revisions,
  automatic UTF-16 detection, previews, stale-context rejection, approval and
  cancellation, archive linkage forms, removal, undo and restoration.
- Live HTTP check at http://127.0.0.1:8797: status 200; lang="en", "Your
  workspace", "Missing information" and "Data and configuration" present.
  Former Italian navigation labels absent from the response.
- Reviewed the four changed interface files and searched R sources for remaining
  Italian interface phrases; no matches. git diff --check is clean.
- Initial targeted test invocation omitted the Windows locale settings and
  encountered encoding warnings in a UTF-16 fixture. The complete rerun above
  uses the documented environment and passes without warnings.

Raw full-suite output is kept locally in
evidence/2026-11-26-english-tests.txt (ignored by Git). The pre-publication rerun also passed all 928 assertions; its output is in evidence/2026-11-26-english-publication-tests.txt.

## Manual checks and limits

The English browser checklist is in ../user-guide/shiny-workspace.md. Browser
automation failed to start, so visual layout and interactive browser checks
have not been verified in this session. Module tests and the live HTTP response
are the completed checks; they do not constitute a visual browser inspection.

The review app uses the existing local review runtime at
C:/Users/tina_/AppData/Local/ecodata/plain-zip-review-20261125-verified.
Opening the page alone does not approve suggested settings or mappings.
No source registrations or clarification approvals were made for this translation.

The user approved the English translation and publication of the interface changes, tests and updated documentation on 26 November 2026.
