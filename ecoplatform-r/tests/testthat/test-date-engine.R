date_fixture <- function(repo, text, split = FALSE, confirmed = TRUE, order = NULL,
  enabled_patterns = NULL, enabled_rules = NULL, pattern_version = "date-patterns-0.1") {
  v <- register_input(write_fixture(text), list(title = "Synthetic dates"), repo)
  headers <- if (split) c("anno", "giorno", "mese") else c("id", "date")
  table <- new_validation_table(v$version_id, v$resource_ids[[1]], headers)
  mapping <- new_date_mapping(table, "sampling", "sampling_date",
    if (split) c(year = 0, day = 1, month = 2) else c(value = 1),
    if (confirmed) "user" else "suggested", "tester", "Synthetic role declaration", confirmed,
    date_order = order, date_order_evidence = if (is.null(order)) "" else "Synthetic documented order")
  spec <- new_validation_spec(list(mapping), enabled_patterns = enabled_patterns,
    enabled_rules = enabled_rules, pattern_version = pattern_version)
  cfg <- make_config(repo, v$version_id, validation_spec = spec)
  list(v = v, cfg = cfg, mapping = mapping)
}

date_rows <- function(result) result$mappings[[1]]$rows
date_labels <- function(result) vapply(date_rows(result), function(x) x$status, character(1))
date_ids <- function(row) vapply(row$candidates, function(x) x$pattern_id, character(1))

test_that("mixed date strings retain lexical ambiguity, originals and reconciled counts", {
  repo <- new_test_repo()
  f <- date_fixture(repo, paste0("id,date\n1,2020-03-15\n2,2020-02-30\n3,03/04/2020\n",
    "4,2020\n5,2020-03\n6,2020-03-15T14:30:00Z\n7,2020-03-15/2020-03-20\n",
    "8,\n9,spring 2020\n10,NA\n11,2020-3-15\n12, 2020-03-15\n13,31/12/2020\n"))
  out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id)
  expect_equal(date_labels(out), c("recognised", "recognised", "ambiguous", rep("recognised", 4),
    "missing", rep("unrecognised", 4), "ambiguous"))
  expect_equal(date_ids(date_rows(out)[[3]]), c("dmy-slash", "mdy-slash"))
  expect_equal(date_ids(date_rows(out)[[13]]), c("dmy-slash", "mdy-slash"))
  expect_equal(date_rows(out)[[2]]$original_values$value, "2020-02-30")
  expect_equal(date_rows(out)[[12]]$original_values$value, " 2020-03-15")
  expect_equal(unlist(date_rows(out)[[7]]$candidates[[1]]$pattern$endpoint_patterns), rep("ymd-dash", 2))
  m <- out$mappings[[1]]
  expect_equal(unlist(m$summary$counts), c(ambiguous = 2, incomplete = 0, missing = 1,
    not_evaluated = 0, recognised = 6, unrecognised = 4))
  expect_equal(m$pattern_counts[["dmy-slash"]], 2)
  expect_equal(m$pattern_counts[["mdy-slash"]], 2)
  expect_equal(m$evaluated_rows, 13)
  expect_equal(m$checks[[length(m$checks)]]$rule_id, "TMP-08")
  expect_false(out$calendar_validation)
  expect_equal(out, decode_json(json_text(out)))
})

test_that("documented order and enabled patterns filter candidates without guessing", {
  repo <- new_test_repo()
  f <- date_fixture(repo, "id,date\n1,03/04/2020\n2,2020-03-15\n3,03-04-2020\n", order = "DMY")
  out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id)
  expect_equal(date_ids(date_rows(out)[[1]]), "dmy-slash")
  expect_equal(date_ids(date_rows(out)[[2]]), "ymd-dash")
  expect_equal(date_ids(date_rows(out)[[3]]), "dmy-dash")
  f <- date_fixture(repo, "id,date\n1,03/04/2020\n2,2020-03-15\n", enabled_patterns = "mdy-slash")
  expect_equal(date_labels(run_date_validation(repo, f$v$version_id, f$cfg$config_id)),
    c("recognised", "unrecognised"))
  f <- date_fixture(repo, "id,date\n1,2020\n2,\n", enabled_patterns = character())
  expect_equal(date_labels(run_date_validation(repo, f$v$version_id, f$cfg$config_id)), c("unrecognised", "missing"))
})

test_that("named split roles preserve widths and distinguish incomplete from missing", {
  repo <- new_test_repo()
  f <- date_fixture(repo, "anno,giorno,mese\n2020,7,03\n2020,07,\n,,\n2020,007,03\n2020,99,99\n2020,NA,03\n", split = TRUE)
  out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id)
  expect_equal(date_labels(out), c("recognised", "incomplete", "missing", "unrecognised", "recognised", "unrecognised"))
  expect_equal(date_rows(out)[[1]]$observed_widths, list(day = 1, month = 2, year = 4))
  expect_equal(unlist(date_rows(out)[[2]]$missing_components), "month")
  expect_equal(date_rows(out)[[1]]$original_values, list(day = "7", month = "03", year = "2020"))
  expect_equal(date_rows(out)[[1]]$mapping$columns$day$original_header, "giorno")
  expect_equal(out$mappings[[1]]$summary$counts$incomplete, 1)
})

test_that("new executable catalogue and historical snapshots both remain usable", {
  repo <- new_test_repo()
  old <- date_patterns()
  current <- date_patterns("date-patterns-1.0")
  expect_equal(current$patterns, old$patterns)
  expect_false(current$calendar_validation)
  for (version in c("date-patterns-0.1", "date-patterns-1.0")) {
    f <- date_fixture(repo, "id,date\n1,2020-02-30\n", pattern_version = version)
    out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id)
    expect_equal(date_labels(out), "recognised")
    expect_equal(date_rows(out)[[1]]$pattern_catalogue_version, version)
    expect_equal(get_configuration(repo, f$cfg$config_id)$validation_spec$patterns$version, version)
  }
})

test_that("unconfirmed mappings and disabled mandatory rules never authorise recognition", {
  repo <- new_test_repo()
  f <- date_fixture(repo, "id,date\n1,2020\n2,\n", confirmed = FALSE)
  out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id)
  expect_equal(date_labels(out), rep("not_evaluated", 2))
  expect_equal(out$mappings[[1]]$summary$counts$not_evaluated, 2)
  expect_equal(out$mappings[[1]]$evaluated_rows, 0)
  f <- date_fixture(repo, "id,date\n1,2020\n", enabled_rules = c("TMP-00", "TMP-01", "TMP-08"))
  out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id)
  expect_equal(date_labels(out), "not_evaluated")
  expect_match(out$mappings[[1]]$reason, "TMP-02")
  f <- date_fixture(repo, "id,date\n1,2020\n", enabled_rules = character())
  out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id)
  expect_length(date_rows(out), 0)
  expect_equal(out$mappings[[1]]$not_evaluated_rows, 1)
})

test_that("each date role has its own population and total output budget", {
  repo <- new_test_repo()
  v <- register_input(write_fixture("sample,analysis\n2020,03/04/2020\n2020-03,2020-02-30\n"), list(), repo)
  table <- new_validation_table(v$version_id, v$resource_ids[1], c("sample", "analysis"))
  a <- new_date_mapping(table, "sampling", "sampling_date", c(value = 0), "user", "tester", "Synthetic", TRUE)
  b <- new_date_mapping(table, "analysis", "analysis_date", c(value = 1), "user", "tester", "Synthetic", TRUE)
  cfg <- make_config(repo, v$version_id, validation_spec = new_validation_spec(list(a, b)))
  out <- run_date_validation(repo, v$version_id, cfg$config_id)
  expect_equal(vapply(out$mappings, function(m) m$evaluated_rows, numeric(1)), c(2, 2))
  expect_equal(out$mappings[[2]]$summary$counts$ambiguous, 1)
  limited <- run_date_validation(repo, v$version_id, cfg$config_id, max_output_rows = 3)
  expect_equal(vapply(limited$mappings, function(m) m$status, character(1)), c("completed", "limited"))
  expect_length(limited$mappings[[2]]$rows, 0)
  expect_equal(limited$mappings[[2]]$not_evaluated_rows, 2)
  selected <- run_date_validation(repo, v$version_id, cfg$config_id, mapping_id = "analysis")
  expect_length(selected$mappings, 1)
  expect_equal(selected$mappings[[1]]$mapping_id, "analysis")
  expect_error(run_date_validation(repo, v$version_id, cfg$config_id, mapping_id = "foreign"), "mapping_id")
})

test_that("descriptor dates run despite an absent measurement member and saved missing date", {
  repo <- new_test_repo()
  f <- full_fixture(repo, full_archive(include_extension = FALSE))
  missing <- new_validation_table(f$v$version_id, f$v$resource_ids[1], "date", "absent.csv")
  mapping <- new_date_mapping(missing, "absent", "analysis_date", c(value = 0), "user", "tester", "Saved absent member", TRUE)
  cfg <- make_config(repo, f$v$version_id, expected_revision = 1L, validation_spec = new_validation_spec(list(mapping)))
  out <- run_date_validation(repo, f$v$version_id, cfg$config_id)
  good <- Filter(function(m) m$status == "completed", out$mappings)
  expect_length(good, 1)
  expect_equal(good[[1]]$summary$counts$recognised, 1)
  expect_equal(good[[1]]$summary$counts$ambiguous, 1)
  expect_equal(good[[1]]$context$validation_spec$date_mappings[[1]]$source, "descriptor")
  absent <- Filter(function(m) identical(m$mapping_id, "absent"), out$mappings)[[1]]
  expect_equal(absent$status, "not_evaluated")
  expect_null(absent$population_count)
  expect_null(absent$summary)
  expect_true(any(vapply(out$linkage_prerequisites, function(p) p$status == "not_evaluated", logical(1))))
})

test_that("stale schemas and empty populations are distinguished without inventing values", {
  repo <- new_test_repo()
  f <- date_fixture(repo, "id,date\n1,2020\n")
  wrong <- new_validation_table(f$v$version_id, f$v$resource_ids[1], c("id", "renamed"))
  mapping <- new_date_mapping(wrong, "stale", "sampling_date", c(value = 1), "user", "tester", "Stale header", TRUE)
  cfg <- make_config(repo, f$v$version_id, expected_revision = 1L, validation_spec = new_validation_spec(list(mapping)))
  out <- run_date_validation(repo, f$v$version_id, cfg$config_id, mapping_id = "stale")
  expect_equal(out$mappings[[1]]$evaluated_rows, 0)
  expect_length(date_rows(out), 0)
  expect_match(out$mappings[[1]]$reason, "schema/headers")
  empty <- date_fixture(repo, "id,date\n")
  out <- run_date_validation(repo, empty$v$version_id, empty$cfg$config_id)
  expect_equal(out$status, "completed")
  expect_equal(out$mappings[[1]]$population_count, 0)
  expect_equal(sum(unlist(out$mappings[[1]]$summary$counts)), 0)
})

test_that("recognition survives restart without creating configurations or operations", {
  repo <- new_test_repo()
  f <- date_fixture(repo, "id,date\n1,2020-02-30\n2,03/04/2020\n")
  before <- list_configurations(repo, f$v$version_id)
  first <- run_date_validation(repo, f$v$version_id, f$cfg$config_id)
  expect_equal(list_configurations(repo, f$v$version_id), before)
  expect_equal(nrow(list_operations(repo)), 0)
  expect_true(verify_input(repo, f$v$version_id)$ok)
  close_repository(repo)
  reopened <- open_repository(repo$root)
  withr::defer(close_repository(reopened))
  expect_equal(run_date_validation(reopened, f$v$version_id, f$cfg$config_id), first)
  expect_equal(list_configurations(reopened, f$v$version_id), before)
})

test_that("Unicode blanks, anchored patterns and unsupported variants preserve exact input", {
  repo <- new_test_repo()
  f <- date_fixture(repo, paste0("id,date\n1,\u00a0\n2,\"2020-03-15\n\"\n3,2020-03-15T14:30:00+01:00\n",
    "4,2020-03-15T14:30:00.1Z\n5,03/04/20\n6,2020-99-99T99:99:99Z\n7,2020-99-99/0000-00-00\n"))
  out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id)
  expect_equal(date_labels(out), c("missing", rep("unrecognised", 4), "recognised", "recognised"))
  expect_equal(date_rows(out)[[2]]$original_values$value, "2020-03-15\n")
  expect_equal(date_rows(out)[[1]]$original_values$value, "\u00a0")
})

test_that("cancellation during row construction and summary discards partial output", {
  repo <- new_test_repo()
  for (confirmed in c(TRUE, FALSE)) {
    f <- date_fixture(repo, paste0("id,date\n", paste(rep("1,2020", 130), collapse = "\n"), "\n"), confirmed = confirmed)
    flag <- FALSE; built <- 0L; construct <- date_result_from_validated
    testthat::with_mocked_bindings({
      out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id, cancelled = function() flag)
      expect_equal(out$status, "cancelled")
      expect_length(date_rows(out), 0)
      expect_null(out$mappings[[1]]$summary)
      expect_equal(out$mappings[[1]]$evaluated_rows, 0)
      expect_lte(built, 128)
    }, date_result_from_validated = function(...) { row <- construct(...); built <<- built + 1L; flag <<- TRUE; row }, .package = "ecodata")
  }
  f <- date_fixture(repo, "id,date\n1,2020\n")
  flag <- FALSE; validate <- validate_row_result
  testthat::with_mocked_bindings({
    out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id, cancelled = function() flag)
    expect_equal(out$status, "cancelled")
    expect_length(date_rows(out), 0)
  }, validate_row_result = function(...) { x <- validate(...); flag <<- TRUE; x }, .package = "ecodata")
})

test_that("changed sources invalidate date populations while independent sources continue", {
  repo <- new_test_repo()
  v <- register_input(c(full_archive(), full_archive()), list(), repo)
  cfg <- make_config(repo, v$version_id)
  verify <- verify_input; calls <- 0L
  testthat::with_mocked_bindings({
    out <- run_date_validation(repo, v$version_id, cfg$config_id)
    damaged <- Filter(function(m) m$resource_id == v$resource_ids[1], out$mappings)
    expect_true(all(vapply(damaged, function(m) m$status == "unreadable", logical(1))))
    expect_true(all(vapply(damaged, function(m) is.null(m$population_count), logical(1))))
    expect_true(all(vapply(damaged, function(m) length(m$rows) == 0, logical(1))))
    p <- Filter(function(p) p$resource_id == v$resource_ids[1], out$prerequisites)
    expect_true(all(vapply(p, function(p) p$status == "not_evaluated" && is.null(p$population_count), logical(1))))
    sibling <- Filter(function(m) m$resource_id == v$resource_ids[2] && m$status == "completed", out$mappings)
    expect_length(sibling, 1)
    expect_equal(sibling[[1]]$evaluated_rows, 2)
  }, verify_input = function(repo, version_id) {
    calls <<- calls + 1L
    if (calls == 3L) writeBin(charToRaw("changed"), get_input(repo, version_id)$resources$owned_path[1])
    verify(repo, version_id)
  }, .package = "ecodata")
})

test_that("invalid arguments, removed inputs and stale lifecycle revisions are rejected", {
  repo <- new_test_repo()
  f <- date_fixture(repo, "id,date\n1,2020\n")
  expect_error(run_date_validation(repo, "foreign", f$cfg$config_id), "different version")
  expect_error(run_date_validation(repo, f$v$version_id, f$cfg$config_id, cancelled = FALSE), "function")
  expect_error(run_date_validation(repo, f$v$version_id, f$cfg$config_id, cancelled = function() NA), "cancellation")
  expect_error(run_date_validation(repo, f$v$version_id, f$cfg$config_id, max_output_rows = -1), "max_output_rows")
  expect_error(run_date_validation(repo, f$v$version_id, f$cfg$config_id, expected_workspace_revision = 99), "revision|changed")
  set_workspace_state(repo, f$v$version_id, "removed", 0L, "date-remove", "tester")
  expect_error(run_date_validation(repo, f$v$version_id, f$cfg$config_id), "removed|active")
})

test_that("a single cancellation request remains effective across the entire run", {
  repo <- new_test_repo()
  f <- date_fixture(repo, "id,date\n1,2020\n")
  calls <- 0L
  out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id,
    cancelled = function() { calls <<- calls + 1L; calls == 1L })
  expect_equal(out$status, "cancelled")
  expect_true(all(vapply(out$mappings, function(m) m$evaluated_rows == 0L, logical(1))))
  expect_true(all(vapply(out$mappings, function(m) length(m$rows) == 0L, logical(1))))
})
