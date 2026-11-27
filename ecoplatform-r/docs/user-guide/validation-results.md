# Run validation and inspect saved results

Use R 4.4 or later and restore the pinned dependencies with `renv::restore()`.
The background worker uses `callr` and `ps`, already recorded in renv.lock.
Launch with `Rscript --vanilla tools/launch-shiny.R` from ecoplatform-r/.
Stop older app processes before using this version on an existing runtime:
it upgrades SQLite to v3 after making a verified backup. Keep runtime storage
outside Dropbox/OneDrive. Older versions cannot open a v3 runtime.

## Run a check

For the new guided **date-format** workflow, use **Save and generate preview**,
**Next**, select date fields/formats, then **Run validation** under Missing
information. This runs dates only and compares each value to its declared format;
see [date-workflow.md](date-workflow.md). The general Validation tab below retains
its existing combined linkage/date behaviour for other saved configurations.

1. Register/select a source version and a saved reading configuration.
2. Under **Missing information**, review any required technical settings or
   date/relationship mappings. Suggestions are drafts: review an exact answer,
   then **Approve and save** to create a new configuration revision.
3. Open **Validation** and check the displayed revision. A run covers **all files
   in this source version**, using that exact revision. Usable descriptor mappings
   are resolved automatically; unknown or unconfirmed roles remain unevaluated.
4. Select **Run validation**. Linkage and date-pattern progress are shown separately.
   The worker runs outside the interactive request; other tabs remain usable.
5. Open **Results** and select the saved run. Read the coverage explanations as
   well as the counts. Completed means execution finished, not that the data passed.

**Cancel run** requests cooperative cancellation and discards partial scientific
results. Queued runs cancel immediately. If a worker stops unexpectedly, **Recover
stopped run** becomes available when its recorded PID/birth time is proven absent.
An active worker cannot be interrupted by opening another session or pressing recovery.
Submit a new run after interruption; terminal history is not overwritten.

While queued or running, an indeterminate **Validation progress** bar displays
the current saved stage messages. It does not claim a percentage or remaining
time; it disappears once the run completes, fails, is interrupted or is cancelled.

## Read the output

- **Date classifications** preserve original values, field names/positions,
  date role, candidate formats, observed widths and missing components. An
  undocumented `03/04/2020` retains DMY and MDY interpretations. `2020-02-30`
  matches YYYY-MM-DD lexically; this says nothing about calendar validity.
- **Linkage outcomes** show exact references and target locators. Repeated
  measurements can legitimately link to one unique occurrence. Ambiguous,
  missing and unresolved references remain distinct.
- **Findings** show rule, severity, original values, affected source-row locators
  and an explanation. One repeated-key group can target multiple source rows.
- **Check coverage** separates applicability, execution, known/unknown population
  and evaluated counts. A readable date field can run even when linkage is blocked.

Use **Show**, **Filter**, **Rows per page** and **Page** for SQL-backed details.
The matching-record total refers to saved detail records. Coverage separately
explains rows not materialised because of missing mappings or quotas; they must
not be interpreted as successful checks. Expand **Source and configuration
provenance** to see exact versions and hashes. History labels previews and
validation operations separately.

The default output budget is 25,000 rows per family; full-table reader limits
remain 50 MiB, one million rows and five million decoded fields per table.
These limits are disclosed rather than presenting a bounded preview as a full run.
Background execution is available, but a production workload/concurrency envelope
has not yet been qualified.

Saved results survive restart, parser revisions and reversible removal. Under
**Removed**, select the version and inspect **Results**. Restore it before running
new validation. Removal is blocked while any operation is queued or running.
Original files are never corrected, converted, merged or deleted by validation.

## Synthetic demonstration

Run `Rscript --vanilla tools/manual-validation.R`. It creates an isolated runtime
and a small declared archive, starts a real background worker, checks pagination,
then demonstrates removal/restoration, a later configuration and repository restart.
Set `ECODATA_VALIDATION_ROOT` to a new local directory to retain the demo for Shiny;
existing directories are refused. The script uses no research data or research approvals.

Expected saved details: seven date records (recognised 4, ambiguous 1, missing 1,
unrecognised 1); nine linkage outcomes (linked 4, ambiguous 1, missing reference 1,
unresolved reference 3); ten findings. The measurement table has no confirmed date
role and is explicitly unevaluated. Overall status is Completed with limitations.
Evidence is written under ignored evidence/shiny-validation/.
