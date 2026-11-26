# Recognise date formats: Task 2D

This increment exposes an R service. Shiny's upload, clarification and preview
workflow remains available; its validation button and saved results belong to
Task 2E. A preview is not a full date assessment.

From `ecoplatform-r/`, with R 4.4 or later and the existing project library:

```text
Rscript --vanilla tools/manual-dates.R
```

On Windows use `LANG=en_US.UTF-8` and `LC_ALL=English_United States.utf8`.
Set `ECODATA_R_LIBRARY` to the prepared development library if needed.
The demonstration creates a new temporary local runtime. An optional
`ECODATA_DATES_ROOT` must name a directory that does not yet exist. It uses only
synthetic data and makes no approvals for research datasets.

Expected single-field results: nine rows, six recognised, one ambiguous, one
missing and one unrecognised. The same table's independent split group produces
six recognised, one incomplete, one missing and one unrecognised. All 18 typed
records are identical after closing/reopening the repository. Original files and
configuration hashes remain unchanged; validation creates no operation records.
Ignored evidence JSON is written under `evidence/dates/` for manual inspection.

## Run on an existing registered source

```r
pkgload::load_all(".")
repo <- open_repository("ABSOLUTE_LOCAL_RUNTIME")
result <- run_date_validation(repo, version_id, config_id)
lapply(result$mappings, function(m) list(
  mapping_id = m$mapping_id, status = m$status, reason = m$reason,
  population = m$population_count, evaluated = m$evaluated_rows,
  not_evaluated = m$not_evaluated_rows, unclassified = m$unclassified_rows,
  counts = if (is.null(m$summary)) NULL else m$summary$counts,
  patterns = m$pattern_counts))
close_repository(repo)
```

Use `mapping_id` to select one exact mapping. A usable descriptor eventDate can
run directly; a suggested field needs explicit role confirmation. User mappings
may declare a single `value` position or named `day`, `month`, `year` positions,
all zero-based. Multiple roles in one table are evaluated separately. For a new
specification select `pattern_version = "date-patterns-1.0"` explicitly; saved
older specifications retain their own version.

## Interpret results

| Example | Outcome |
|---|---|
| `2020-03-15`, `2020-02-30` | Recognised YYYY-MM-DD structure for both |
| `03/04/2020`, without documented order | Ambiguous DMY and MDY candidates |
| `31/12/2020`, without documented order | Also lexically ambiguous; ranges do not choose order |
| `2020`, `2020-03` | Recognised partial date |
| `2020-03-15T14:30:00Z` | Recognised timestamp structure |
| `2020-03-15/2020-03-20` | Recognised interval, both endpoint patterns recorded |
| year `2020`, day `7`, month `03` | Recognised split components, widths 4/1/2 preserved |
| A split group with one or two blank components | Incomplete; missing components listed |
| A blank field or entirely blank split group | Missing |
| `NA`, `spring 2020`, `2020-3-15` | Unrecognised by the initial enabled formats |

Recognised means a format match. Calendar validity, date conversion, interval
ordering, timezone-offset/fractional timestamps, natural language, two-digit
years and unlisted formats are outside this increment. Leading/trailing
whitespace on a nonblank expression is preserved and prevents a match.

For coverage checks, compare each summary with its mapping's known population.
Candidate-pattern totals include both interpretations of ambiguous rows and are
not mutually exclusive row totals. Missing mappings, unreadable members, stale
schemas, disabled mandatory rules and quotas disclose limitations. An unreadable
measurement member does not block an independent readable occurrence date.
Set `max_output_rows` to a positive whole-run record limit or pass a cooperative
`cancelled` function. Cancellation discards partial results. Rerun after reopening
to reproduce results; this stage does not store validation runs in app history.
