# First Shiny interface implementation plan

Authorised scope: the user's approval of the first interface on 2026-11-24: upload/inspect files, edit and save parser revisions, consult operation history, run locally and show the platform. No commit or push until subsequent explicit approval. Scientific validation, findings review, harvesting and reporting remain out of scope.

## Design and decisions

Use the existing modular R/SQLite foundation, adding a local Shiny app with three Italian-labelled views: Dati e configurazione, Anteprima, Storico. A persistent source/resource selector distinguishes files even when names repeat. Each session owns its database connection. The existing foundation feature branch remains uncommitted.

Choose one Shiny module and focused pure services over a separate API, since the approved foundation is already R and the workload is bounded. Keep presentation, service orchestration and storage separate. Use the installed Shiny/bslib libraries and local stylesheet; no external assets or network requests are necessary to use the app.

Uploads preserve browser original filenames independently of Shiny's temporary paths. Explicit registration owns immutable copies and creates a first parser configuration. Selecting a historical revision is read-only. Saving edits requires the displayed resource/version/config context and latest revision; stale browser events cannot silently apply to a different source. Every inspection logs an operation with frozen input/config and exposes limitations rather than a scientific pass.

## Files and tasks

1. R/input_registration.R optional original_names contract, R/service_workspace.R upload/inspection services; regression tests for original names, missing/unsafe uploads, immutable snapshots and history.
2. R/app_ui.R, R/mod_workspace.R, R/run_app.R, app.R and tools/launch-shiny.R; Shiny testServer cases for registration, parser changes, stale form rejection, historical snapshots and logged inspection. Local CSS under inst/www/.
3. Document setup/manual browser workflow and launch/runtime locations; update dependency lock. Run the complete foundation+UI suite and package build/check. One independent final review, correct actionable issues with regression tests.
4. Launch a persistent localhost process on an unused port, open it visibly and inspect the real browser workflow, including a narrow layout. Retain evidence and show the live URL. Leave all work uncommitted/unpushed for review.

Acceptance: actual file upload survives upload-temp removal; changing dropdowns alone writes nothing; saving records a new revision; old previews/history retain original context; unsupported resources have readable limitations; browser shows no raw errors or false scientific validity claims. No app connection is shared across sessions or closed by another session.
