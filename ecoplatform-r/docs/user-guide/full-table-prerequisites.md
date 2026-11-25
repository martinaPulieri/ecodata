# Manual checks: complete tables and prerequisites

Run from ecoplatform-r/ with the project R library:

    Rscript --vanilla tools/manual-full-tables.R

Set ECODATA_EXAMPLES to the absolute data_examples directory if it is elsewhere.
Use the same documented UTF-8/English locale as tools/test-step1.R on Windows.
The script uses a new temporary repository, never your existing workspace.
Evidence is written to evidence/full-tables/manual-result.json and excludes
research records. The script registers inputs, reads every declared table,
checks source hashes and proves that preparation adds zero history operations.

For interactive inspection:

    pkgload::load_all(".")
    repo <- open_repository(tempfile("manual-full-"))
    path <- "ABSOLUTE_PATH_TO_DATASET.csv"
    upload <- data.frame(name=basename(path), size=file.info(path)$size,
                         type="", datapath=path)
    v <- register_uploaded_inputs(repo, upload, "Manual input", "operator")
    x <- read_validation_tables(repo, v$version_id, v$config_id)
    p <- assess_validation_prerequisites(x)
    lapply(x$tables, function(t) list(status=t$status,
        rows=t$population_count, columns=names(t$data)))
    lapply(p$linkage, function(c) c[c("status","reason")])
    lapply(p$dates, function(c) c[c("status","reason")])
    close_repository(repo)

Inspect status before interpreting data. For Venezia, verify complete reading,
UTF-16LE/tab settings and more rows than the 20-row preview. Date candidates
require confirmation: they do not certify date validity.

Boundary checks (use the synthetic unit tests for repeatable fixtures):
1. Set max_rows=1, max_table_bytes=5 or max_cells=3. Expect limited and an
   unknown population, never complete coverage.
2. Set cancelled=function() TRUE. Expect cancelled and no assessed population.
3. Remove an extension member while retaining its meta.xml declaration. Expect
   linkage not_evaluated, with the readable core eventDate still ready.
4. Change only coreid to an out-of-range index. Date preparation stays ready.
   Change only eventDate index: usable linkage prerequisites stay ready.
5. Save a confirmed mapping with different headers. Expect not_evaluated.
   Leave a candidate unconfirmed: expect not_evaluated.
6. Check literal NA, leading-zero identifiers and quoted multiline cells remain
   exact strings. Locator row numbers count data records, not physical lines.
7. Confirm source hashes and operation count do not change during preparation.

ready is prerequisite readiness only. No rows have been scientifically evaluated.
The Shiny application remains on its existing preview workflow until Task 2E.
