# Task 2D: lexical date recognition

`run_date_validation()` reads exact registered/configured tables, resolves
independent TMP-00 prerequisites, then executes TMP-01/02 for a single field or
TMP-03 for a named split group, followed by TMP-08 reconciliation. It does not
invoke linkage matching. The pure evaluator in `R/validation_temporal.R` consumes
the same `validation-preparation-1.0` structure without SQLite writes.

Each effective mapping receives a frozen context containing the original
configuration hash, source resource hash, workspace revision, exact field roles,
positions, headers and catalogue snapshots. Descriptor mappings retain their
meta.xml evidence. Saved descriptor declarations are supplemented in the execution
context with the actual descriptor member, digest and field index; their original
stored evidence/configurations remain unchanged. Effective contexts contain one mapping, so stale or unreadable
siblings cannot invalidate an independent field. Suggested mappings never
authorise recognition; readable unconfirmed fields receive `not_evaluated`
records when their exact schema and the output budget permit.
Unconfirmed or stale saved mappings cannot suppress usable descriptor fields.

## Patterns and provenance

The executable `date-patterns-1.0` catalogue retains the initial definitions of
`date-patterns-0.1`. Historical files and their hashes are unchanged. Existing
specifications continue to use their pinned version; `new_validation_spec()`
retains its historical default and accepts explicit `pattern_version` selection.
Descriptor-only execution without a saved specification uses 1.0. The engine
version `lexical-dates-1.0` records which matcher executed either catalogue.

Full-string ASCII numeric matching uses the catalogue's fixed widths and
separators. Year-last DMY/MDY candidates remain ambiguous unless documented
order or the enabled-pattern policy filters them. Numeric component values do
not resolve lexical ambiguity. Unicode blanks are missing; nonblank whitespace,
literal NA and leading zeros remain unchanged. Split roles follow their names,
independently of physical column order. No Date/POSIXct conversion, trimming,
calendar ranges, timezone interpretation or interval ordering is performed.

Each row record includes its original values, row locator, mapping, observed
widths and complete candidate pattern definitions. Interval definitions include
both endpoint patterns. Summaries count each row once per mapping across all six
statuses. `pattern_counts` count candidate memberships, including ambiguous
rows; their sum can therefore exceed the recognised-plus-ambiguous row count.
TMP-01 screens the whole mapped population; TMP-02 coverage counts nonmissing
values only. TMP-03 and TMP-08 include all rows of their mapped field/group.

The frozen context is validated once at each mapping/summary boundary. An internal
constructor reuses that validated context while checking and hashing every row's
values, status, candidates and provenance. Exported standalone constructors still
validate caller-supplied contexts. Summary reconciliation checks every record's
hash, payload and unique source-row identity without reloading invariant catalogues
for each row. Catalogue-read counts are regression-tested independently of row count.

## Coverage and execution boundaries

The read-only return contract is `date-evaluation-1.0`. A mapping reports
`completed`, `not_evaluated`, `limited`, `unreadable` or `cancelled`, along with
known/unknown population, evaluated rows, not-evaluated rows, row records,
unclassified rows, summary and check records. `completed` describes execution,
not scientific validity. Unclassified rows count records not materialised;
they must never be counted as recognised rows.

The default whole-run output budget is 25,000 row records, shared across mappings,
including explicit not-evaluated records. A mapping that would exceed the
remaining budget is limited without partial recognition. Reader limits remain
50 MiB, one million rows and five million decoded fields per table. Unknown or
incompletely read populations remain NULL. Cancellation is cooperative during
reading, row construction and summary validation; cancelled runs retain no row
classifications. Source integrity is checked before/after preparation and after
evaluation. Changed resources lose output, population claims and readiness;
healthy siblings remain available. Lifecycle revisions are checked before returning.
Cancellation is latched for the whole run, including requests made before a
targeted descriptor mapping can be rediscovered. In that case the requested ID
is retained as a selection, with no invented mapping, population or row results.

SQLite stays at v2. Neither the evaluator nor the service appends configurations,
operations, findings or result rows. Task 2E owns durable results, migration,
background workers and Shiny validation/results controls. Broader RF10 calendar
validity and a complete review workflow remain later work.
