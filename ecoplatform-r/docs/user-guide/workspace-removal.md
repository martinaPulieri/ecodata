# Reversible removal from the workspace

In **Registered data**, choose **Active** and a **Source version**, then
**Remove from workspace**. The confirmation names the exact version, every
file and the number of configurations and operations retained. **Keep in workspace** cancels without writing an event.

Removal applies to the selected uploaded source version and all its files.
Other deliveries in the same dataset are unaffected. Active selectors and the
**Active versions / Active files** counters exclude it; the old preview clears.
Original bytes, configuration revisions, processing history and lineage remain
stored. This action does **not** free disk space or erase data permanently.

Use **Undo removal** for the latest removal in this browser session, or
choose **Removed**, select a version and click **Restore to workspace**.
Restoration selects the original version with its existing configurations;
it does not rerun an inspection. Removed versions expose saved parser settings,
file identifiers/hashes and history in read-only form. **History** includes the
selected version's removal/restoration events and the full operation history.

An input with queued/running operations cannot be removed. Complete or explicitly
resolve those operations through the existing trusted-worker lifecycle API;
removal never cancels work automatically. A stale confirmation, save or preview
request is rejected. Reload the view and retry. Other browser sessions refresh
repository changes approximately every 1.5 seconds; write guards act immediately.
All sessions using the same runtime share membership; it is not per-user hiding.
The operator label records provenance and is not authenticated authorization.

## Manual browser checks

Use a separate local test runtime (outside Dropbox), not a production database.
Start with two uploaded versions, one containing two files with identical names.

1. Generate a preview; record counts, configuration revision and operation ID.
2. Open removal. Check version, both files and retained-history counts. Cancel:
   counts, selection and preview remain, and no lifecycle event is added.
3. Confirm removal. Both files disappear together from Active; counts decrease;
   preview clears and the other version remains. No file is deleted.
4. Click Undo removal. The exact version returns. Generate its preview again
   with the same revision; compare values and original SHA-256.
5. Remove again, reload the page, choose Removed. Inspect saved settings and
   History. Save/detect/preview actions are unavailable. Restore and confirm
   existing configuration IDs and operation history remain unchanged.
6. Open two browser sessions. Keep a confirmation open in A; remove and restore
   the same version in B. Confirm in A: rejected, with no additional removal.
   An old configuration form must also be rejected after this cycle.
7. Queue an operation through submit_operation(). Removal must fail for queued
   and running states. After a terminal event, removal is allowed.
8. Remove the last active version: the empty state is usable, file/configuration
   selectors clear, and Removed still allows restoration. Check at mobile width.

## Reproducible checks

From the package directory, with the documented R library configured:

```text
Rscript --vanilla tools/test-step1.R
Rscript --vanilla tools/manual-workspace-removal.R
Rscript --vanilla tools/check-step1.R
```

The acceptance script reads the separately supplied Venezia CSV, registers owned
copies in a new local runtime, removes/reopens/restores and compares hashes,
history and previews. Set ECODATA_VENEZIA_FILE to its absolute location if needed.
ECODATA_REMOVAL_ROOT optionally selects a **new** runtime; existing paths are
refused. Results are saved under ignored evidence/removal/. The CSV is not shipped.
