test_that("targeted descriptor cancellation does not become an unknown mapping error", {
  repo <- new_test_repo()
  f <- full_fixture(repo, full_archive())
  input <- read_validation_tables(repo, f$v$version_id, f$cfg$config_id)
  id <- assess_validation_prerequisites(input)$dates[[1]]$mapping$mapping_id
  out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id,
    mapping_id = id, cancelled = function() TRUE)
  expect_equal(out$status, "cancelled")
  expect_equal(out$requested_mapping_id, id)
  expect_true(all(vapply(out$mappings, function(m) length(m$rows) == 0L, logical(1))))
  expect_true(all(vapply(out$mappings, function(m) is.null(m$population_count), logical(1))))
})

test_that("unconfirmed suggestions cannot suppress a usable descriptor on the same field", {
  repo <- new_test_repo()
  f <- full_fixture(repo, full_archive())
  input <- read_validation_tables(repo, f$v$version_id, f$cfg$config_id)
  proposed <- new_date_mapping(input$tables[[1]]$schema, "suggestion", "proposed_date",
    c(value = 2), "suggested", "tester", "Unconfirmed role proposal")
  cfg <- make_config(repo, f$v$version_id, expected_revision = 1L,
    validation_spec = new_validation_spec(list(proposed)))
  out <- run_date_validation(repo, f$v$version_id, cfg$config_id)
  good <- Filter(function(m) m$status == "completed", out$mappings)
  expect_length(good, 1)
  expect_equal(good[[1]]$evaluated_rows, 2)
  expect_equal(good[[1]]$context$validation_spec$date_mappings[[1]]$source, "descriptor")
  suggestion <- Filter(function(m) identical(m$mapping_id, "suggestion"), out$mappings)[[1]]
  expect_equal(suggestion$summary$counts$not_evaluated, 2)
})

test_that("catalogue reads are bounded per mapping rather than per date row", {
  repo <- new_test_repo()
  counts <- numeric()
  read <- read_validation_catalogue
  for (n in c(1, 20)) {
    f <- full_fixture(repo, full_archive(core = paste0("id,occurrenceID,Date observed\n",
      paste(rep("001,obs-a,2020-02-30", n), collapse = "\n"), "\n")))
    reads <- 0L
    testthat::with_mocked_bindings({
      out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id)
      expect_equal(out$mappings[[1]]$evaluated_rows, n)
    }, read_validation_catalogue = function(...) { reads <<- reads + 1L; read(...) }, .package = "ecodata")
    counts <- c(counts, reads)
  }
  expect_equal(counts[[2]], counts[[1]])
  expect_lte(counts[[2]], 40L)
})
