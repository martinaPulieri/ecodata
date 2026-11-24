# Approved release: input foundation, Shiny and automatic detection

The user approved this implementation for commit and push on 24 November 2026.

## Scope

- Immutable local input copies, SHA-256 integrity checks, independent file identities and dataset delivery lineage.
- Full append-only parser/schema configuration revisions with optimistic concurrency and recorded actors.
- SQLite schema v1, lifecycle history, idempotent submissions, atomic migrations and exclusive verified backups.
- Local Shiny workspace for uploading, configuring, previewing and consulting history, with session-owned connections and stale-context guards.
- Automatic encoding/separator detection for supported CSV/TSV inputs, recorded per resource; manual overrides and explicit redetection preserve old snapshots.

No scientific validation engine, findings review, harvesting or formatted Quarto reporting is included. A successful lexical preview does not establish scientific validity. Authentication, production workload qualification and automatic worker recovery remain later work.

## Executed verification

| Check | Result |
|---|---|
| Complete R test suite | 251 assertions passed; zero failures, errors, warnings or skips |
| R source build and installed-package check | Status: OK; no warnings or notes |
| Real Venezia dataset, new-upload service | UTF-16LE/tab automatically selected in revision 1; preview 20 rows x 235 columns |
| Original Venezia bytes | SHA-256 unchanged: 400b674669fbb216af1ab3836050cb4a4689aa58dc04f1d9433d6880f30afa20 |
| Existing-file redetection | New revision created; original default/manual snapshots retained |
| Browser checks | Configuration save, historical read-only state, preview/context invalidation, limitations, history and reopen verified |
| Responsive checks | 1280 px and 390 px; no page-level horizontal overflow |
| Independent reviews | Concrete parser, archive, migration, backup, UI-error and detection-boundary findings corrected with regression coverage |

Verified environment: R 4.4.3 on Windows; dependency versions are recorded in renv.lock. A full dependency restore on a separate clean machine was not exercised. Native browser file chooser automation was unavailable in the in-app driver; upload logic and temporary-file persistence were verified through Shiny integration tests, and existing actual uploads remained readable after restart.

## Reproduce

From ecoplatform-r/, after restoring dependencies:

```text
Rscript --vanilla tools/test-step1.R
Rscript --vanilla tools/check-step1.R
Rscript --vanilla tools/manual-step1.R
Rscript --vanilla tools/test-autodetection-venezia.R
Rscript --vanilla tools/launch-shiny.R
```

Set ECODATA_R_LIBRARY for an existing development library, ECODATA_VENEZIA_FILE for the user's external dataset path and ECODATA_RUNTIME_ROOT for local non-synchronised persistent data. The Venezia acceptance script requires the original dataset separately; the dataset is not distributed in this repository. The included interface-demo.csv is synthetic.

Generated logs/screenshots remain local under evidence/; tools recreate them. Runtime databases, original research datasets and machine-specific diagnostics are excluded from publication. Detailed manual checks are in the user guides.
