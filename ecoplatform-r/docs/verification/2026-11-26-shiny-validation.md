# Task 2E — persistent validation and Shiny results

Implemented against base efe5916 on 26 November 2026. User authorised implementation,
tests and documentation, with results shown before committing. The user subsequently
approved committing and pushing on 27 November 2026. This report concerns the Tasks 2C/2D validation
subset, not completion of RF08–RF16 or Task 2F workload qualification.

## Delivered behaviour

The **Validation** tab queues exact version/configuration/options and frozen
source/code provenance. A supervised worker owns its SQLite connection and runs
linkage/date families independently. Progress, cancellation and stopped-worker
recovery remain persistent. The **Results** tab queries saved summaries, mapping
coverage, date rows, linkage outcomes, findings/targets and checks with SQL
pagination. Source removal and later configurations do not erase old assessments.

SQLite v3 migration uses a verified committed backup and atomic schema upgrade.
Requests, ownership claims, progress, cancellation and scientific results are
append-only. Final evidence, family progress and terminal state commit together.
Long scans/serialization are outside the writer reservation; one bulk append per
normalised table replaces per-finding writes.

## Executed verification

- Full reviewed-source regression suite: **1,167 passed assertions**, zero failures,
  errors, warnings or skips (116 new assertions beyond the published 1,051 baseline).
- Independent-review regression set: **34 passed**, zero failures/errors/warnings/skips.
- Synthetic background demonstration: seven date records, nine linkage outcomes,
  ten findings with eleven target links; unchanged source bytes; identical saved
  payload after removal/restoration, a new configuration and repository restart.
- Real browser Run created a new revision-2 assessment while other tabs remained
  usable. A subsequent run was cancelled through Shiny; both families ended
  cancelled and Results showed zero saved scientific records. A fresh run then
  completed and its latest Results selection was acknowledged correctly.
- Browser Findings displayed ten records; Warning filter returned exactly three.
  Date details returned seven rows and preserved ambiguous formats and whitespace.
- Desktop 1280×900 and narrow 390×844 layouts were inspected. Narrow page width
  equalled its client width (375 CSS pixels excluding scrollbar), without global
  horizontal overflow. Screenshots are retained in ignored evidence/shiny-validation/.
  Temporary viewport overrides were reset. Browser console error log was empty.
- The first installed-package check passed tests but flagged literal Unicode
  dashes in two R files. Equivalent ASCII-source Unicode escapes preserve visible
  labels. After this correction the final source suite again passed all 1,167
  assertions with zero failures, errors, warnings or skips; the installed-package
  build/check finished with **Status: OK**, with no warnings or notes.
- The app was restarted using this final source. Shiny retained all four recorded
  operations and displayed the latest revision-2 assessment with the same saved
  seven date classifications, nine linkage outcomes and ten findings.

Environment: Windows, R 4.4.3, existing ECODATA_R_LIBRARY,
LANG=en_US.UTF-8 and LC_ALL=English_United States.utf8. callr 3.7.6 and ps 1.9.1
were already installed and pinned in renv.lock; they are now declared Imports.

```text
Rscript --vanilla tools/test-step1.R
Rscript --vanilla tools/check-step1.R
Rscript --vanilla tools/manual-validation.R
```

Package-check evidence is selected through ECODATA_CHECK_EVIDENCE. For the retained
demo ECODATA_VALIDATION_ROOT named a new local directory; existing runtimes are
refused. The app runs at http://127.0.0.1:8799 using
C:/Users/tina_/AppData/Local/ecodata/shiny-validation-review-20261126-final.
The older v2 review runtime and original research datasets were not upgraded or edited.

## Synthetic expected and observed results

| Assessment | Expected and observed |
|---|---|
| Date records | 7: recognised 4, ambiguous 1, unrecognised 1, missing 1 |
| Linkage outcomes | 9: linked 4, ambiguous 1, missing reference 1, unresolved reference 3 |
| Findings | 10: errors 7, warnings 3; eleven source-row target links |
| Measurement dates | No confirmed date role; nine rows disclosed as unevaluated/unclassified coverage |
| Overall status | Completed with limitations; never a dataset pass |
| Preservation | Original hash unchanged; exact payload retained across restart, configuration change and removal |

The archive includes an impossible calendar date (lexically recognised), a
DMY/MDY ambiguity, literal NA identifiers, significant whitespace, repeated core
keys and legitimate multiple measurements per unique occurrence. No research
settings or mappings were approved. Counts refer only to synthetic data.

## Independent review corrections

All nine reported categories were addressed with regression coverage:

1. Run submission no longer hashes original source bytes or scans tables in Shiny.
2. Launcher/supervisor failure uses an atomic queued/unclaimed comparison; it cannot
   fail another process's live claim.
3. Generic audit calls cannot advance managed validation lifecycle. Generic validation
   submission routes to a frozen request; old pre-v3 intents are explicitly cancellable.
4. Source and code checks follow batch preparation. Newly damaged resources are
   discarded/reprepared before publication, and the final verification point is recorded.
5. Invalidated rows lose stale pattern counts/coverage. Final family progress is saved
   atomically, and all-technical-failure status retains precedence over limitations.
6. All normalised records bulk append once per table outside per-finding loops.
7. The Validation panel follows pending work from other sessions; Results stays
   independently selectable and preferred IDs survive until browser acknowledgement.
8. Summary JSON excludes per-core-key multiplicity detail while the full payload retains it.
9. The associated legacy-intent/lifecycle paths preserve historical audit data without
   fabricating a scientific snapshot or stranding new queued requests.

Additional real-worker tests exposed locale-dependent fingerprint ordering and
numeric/POSIXt birth-time handling; both are corrected. An intermediate run had
two real-worker failures from the collation mismatch. Fresh comprehensive evidence
supersedes those intermediate failures. No review finding was deferred. The reviewer
did not duplicate the parent's full suite/package/browser checks or assess Task 2F.

## Evidence and limits

Ignored local evidence includes shiny-validation-final-suite.txt,
shiny-validation-release-suite.txt, persistent-validation-review-final.txt,
shiny-validation-final-manual.txt, shiny-validation-package-release/package-check.txt,
shiny-validation/manual-result.json, synthetic-result.json, live-app-final.json,
results-desktop.jpg and results-mobile.jpg. Red-run logs remain available alongside them.

Completion describes execution. Lexical recognition does not assess calendar
validity. No source correction, harmonisation, exports or full review-decision
workflow is included. Default output budget remains 25,000 rows per family; full
reader quotas and unevaluated populations are disclosed. Production workload and
concurrency qualification remain Task 2F. External writes after the recorded
verification point are outside the SQLite transaction boundary; registered originals
are application-immutable and saved results retain the exact assessed hashes.
