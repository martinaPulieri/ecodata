# Shiny workspace: user guide and manual checks

## Start locally

From the checkout, open ecoplatform-r/ and restore the dependencies described in
the README. Set ECODATA_R_LIBRARY if using an existing local R library, then run:

    Rscript --vanilla tools/launch-shiny.R

The server listens on 127.0.0.1:8791. ECODATA_PORT selects another available port;
ECODATA_RUNTIME_ROOT selects a local, non-synchronised data directory. Without
an override, the app uses the user's R data directory. Keep the active SQLite
database outside Dropbox. The R process must remain running while using the app.

Shiny accepts a request body of 201 MiB. Registration checks actual bytes and
enforces 50 MiB per file and 200 MiB per upload. You can also launch app.R from
RStudio. Each browser session owns its own SQLite connection; registered data
remain available after the session ends.

## Language and stored data

The interface is in English: navigation, controls, notifications, clarification
questions, approval summaries, removal/restoration dialogs and history headings.
New collections default to "New data" and the operator label to "local-reviewer".
The operator label records provenance; it is not an authenticated identity.

User-provided titles, filenames, column headers, source values, evidence and
existing history records retain their original content. Internal status codes
and configuration keys remain stable. The current validation release upgrades
existing runtimes to SQLite v3 with a verified backup; stop older app processes first.

## Manual browser checks

Use a separate test runtime outside Dropbox.

1. Open the local URL. On a fresh runtime, all three counters should show zero.
   Check the English tabs: **Data and configuration**, **Missing information**,
   **Validation**, **Results** and **History**. Preview is now embedded below the
   reading configuration; see [date-workflow.md](date-workflow.md).
2. Under **Add data**, choose tests/fixtures/tabular/interface-demo.csv. Enter a
   **Collection name** and **Operator**, then click **Register inputs**.
   Selecting a file alone does not register it.
3. Check the original filename and revision 1. Automatic detection should report
   UTF-8 and a semicolon delimiter. Identifiers distinguish resources with the
   same filename; Shiny temporary paths do not replace original names.
4. Set **Declared decimal mark** to **Comma (,)**. Controls alone save nothing.
   Click **Save and generate preview**: revision 2 appears and revision 1 remains
   selectable. Historical revisions offer no save button, and stale requests
   are also rejected by the server. **Detect format** explicitly saves a new
   detection revision for previously registered files.
5. Check up to 20 preview rows directly below **Reading configuration**. Values such
   as station 001/002/003, value 1,5/0/<0,1 and date 03/04/25/NA/2025 must remain
   strings; numeric precision and date order are not inferred.
6. Open **History**. A successful preview has queued, running and completed
   events tied to its exact configuration. Unreadable or unsupported resources
   produce completed_with_limitations. Failed integrity checks do not count as
   successful previews.
7. Switch file or configuration: the previous preview must clear. Generate a
   new preview explicitly. Reload the page or open a second session: inputs,
   revisions and history must remain available without rerunning operations.
8. Select **Next** below the preview. **Missing information** opens and runs its
   background check with an indeterminate progress bar. Required date information
   appears as bullet points. Select date fields and confirm/change inferred formats;
   ambiguous values require a choice. **Run validation** saves the declarations and
   starts dates-only checks. No date-role or reason/evidence input is required.
9. Under **Registered data**, choose an active source and **Remove from
   workspace**. Check the exact version and retained-file/history counts.
   **Keep in workspace** cancels. Confirm removal, then use **Undo removal** or
   select **Removed** and **Restore to workspace**. Removed versions are
   read-only; source hashes, configurations and history must be preserved.
10. Narrow the browser below 850 px. Panels should stack vertically and tables
    remain horizontally scrollable. Check that all English controls remain
    reachable and readable.

ZIP archives with meta.xml use the descriptor's parser declarations. Ordinary
ZIP collections require approval of each table's settings in **Missing
information**; see [plain-zip.md](plain-zip.md). The preview uses the selected
version's configuration, and the visible table follows the selected file.

## Code and related guides

- R/app_ui.R: page layout; inst/www/workspace.css: local responsive styling.
- R/mod_workspace.R: registration, parser controls, preview and history.
- R/mod_clarifications.R: questions, draft/review/approval and receipt display.
- R/mod_date_information.R: Next, background information check and date-format controls.
- R/service_workspace_lifecycle.R: removal, restoration and context guards.
- R/service_workspace.R: upload registration and recorded preview services.
- R/run_app.R and tools/launch-shiny.R: session connections and local launch.
- tests/testthat/test-shiny-*.R: module workflows using shiny::testServer.

See [workspace-removal.md](workspace-removal.md) for lifecycle checks and
[clarifications.md](clarifications.md) for the approval workflow. The **Validation**
and **Results** tabs run background checks and inspect persisted evidence; see
[validation-results.md](validation-results.md) for execution, cancellation,
historical results, coverage interpretation and the synthetic demonstration.
