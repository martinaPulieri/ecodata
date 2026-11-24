# Reversible workspace removal — review results

The user reviewed the results and explicitly approved committing and pushing
the reversible-removal code, tests and documentation to martinaPulieri/ecodata.

## Delivered behaviour

- Remove one source version and all its files; other versions remain available.
- Explicit scope confirmation, cancellation, Undo, Removed view and restoration.
- Retained original bytes, configurations, processing history and lineage.
- Active counters/choices exclude removed versions. Last-active removal produces
  a usable empty state; removed versions remain recoverable after reload/restart.
- Removed parser settings and history are read-only. No disk space is reclaimed.
- SQLite v2 append-only lifecycle, idempotent requests, pending-work protection
  and transactional active/stale/ABA guards for new configuration/operation writes.

## Executed checks (2026-11-24)

| Check | Observed result |
|---|---|
| Full R suite | 335 passed assertions, 0 failures/errors/warnings/skips |
| R CMD build / installed R CMD check --no-manual | Status: OK; no warnings or notes |
| Concurrent processes | Removal versus submission permits only one; two removals append once |
| Existing v1 database | Atomic v2 upgrade, preserved source records, verified v1 backup |
| Failed future migration | Schema/user_version rollback preserved |
| Venezia acceptance | Original hash unchanged; restored preview identical, 20 rows × 235 columns |
| Restart | Removed state persisted, then restored without changing history/configuration IDs |
| Browser confirmation/cancel | Exact version/files/retained counts shown; cancel preserved the input |
| Browser removal/Undo | Active count 2→1→2; cached preview cleared; operation count retained |
| Two browser sessions | An old confirmation rejected after another session removed/restored the source |
| Removed view after reload | Saved UTF-16LE/tab settings visible, with restore and no mutation controls |
| Restore older version | Selected the exact restored Venezia version, not the newer sibling |
| Last-active removal | Active versions/files reached zero; usable empty state; both versions restored |
| Unrelated session work | Another version's inspection left the existing Venezia preview visible |
| Mobile confirmation | At 390 px, document width 390 px and dialog width 374.4 px; both actions visible |

Original Venezia SHA-256:
`400b674669fbb216af1ab3836050cb4a4689aa58dc04f1d9433d6880f30afa20`.
The original CSV is separately supplied and is not distributed with this package.

An independent read-only review identified delayed-click identity, selection,
upload-detection and overly broad refresh issues. Regressions reproduced the
failures before the fix pass; the final suite/package checks above include those
fixes. Cancel tokens and archive-specific read-only explanations were also covered.
The reviewer did not independently retest the final fixes; verification was by
the implementing agent through regression tests and browser acceptance.

## Local evidence and review environment

Ignored evidence/removal-final-tests.txt, evidence/removal-precommit-tests.txt and evidence/removal/final-package/
contain final test/build/check logs. evidence/removal/ contains the real-dataset
acceptance JSON and screenshots (homepage.jpg, confirmation.jpg). No research
records, live databases, logs or screenshots are staged for publication.

The review app runs at http://127.0.0.1:8792/ with isolated persistent storage at
`C:/Users/tina_/AppData/Local/ecodata/removal-review-20261124`.
The pre-existing app/runtime on port 8791 was not upgraded or changed.
The review runtime ends with both versions active; processing/removal/restoration
audit events from acceptance remain intentionally available.

## Decisions and limits

- Continue in the existing clean feature checkout; no extra worktree or commits.
- Run R checks with the user's installed library because the sandbox account
  cannot access those packages. No dependency installation was needed.
- Shared independent-process helpers live in testthat helper-concurrency.R;
  testthat isolates each test file's local environment.
- Controlled future migration tests target v3 because v2 is now registered.
- Workspace membership is shared across sessions using the same runtime. Actor
  names are operator labels, not authenticated access controls.
- Stop older application processes before upgrading a shared runtime: an already
  running v1 process cannot enforce the new membership rules.
- Permanent deletion, disk reclamation, automatic job cancellation, scientific
  validation, harvesting and reporting remain outside this increment.

See [manual checks](../user-guide/workspace-removal.md) and
[storage/transaction contracts](../architecture/workspace-lifecycle.md).
