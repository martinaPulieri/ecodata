test_that("saved descriptor mappings retain the actual descriptor evidence at execution", {
  repo <- new_test_repo()
  f <- full_fixture(repo, full_archive(include_extension = FALSE))
  input <- read_validation_tables(repo, f$v$version_id, f$cfg$config_id)
  table <- input$tables[[1]]
  mapping <- new_date_mapping(table$schema, "declared", "eventDate", c(value = 2),
    "descriptor", "tester", "Manually recorded", TRUE)
  cfg <- make_config(repo, f$v$version_id, expected_revision = 1L,
    validation_spec = new_validation_spec(list(mapping)))
  out <- run_date_validation(repo, f$v$version_id, cfg$config_id)
  m <- out$mappings[[1]]
  expect_equal(m$status, "completed")
  expect_match(m$context$validation_spec$date_mappings[[1]]$evidence, table$declaration$descriptor_sha256, fixed = TRUE)
  expect_match(m$rows[[1]]$mapping$evidence, "Manually recorded", fixed = TRUE)
  expect_match(m$rows[[1]]$mapping$evidence, "meta.xml", fixed = TRUE)
  expect_equal(get_configuration(repo, cfg$config_id)$validation_spec$date_mappings[[1]], mapping)
})

test_that("pattern matching coverage counts nonmissing values independently of missing screening", {
  repo <- new_test_repo()
  for (dates in list(c("", ""), c("", "2020-02-30", "spring 2020"))) {
    f <- full_fixture(repo, full_archive(core = paste0("id,occurrenceID,Date observed\n",
      paste(paste0("001,obs,", dates), collapse = "\n"), "\n"), include_extension = FALSE))
    out <- run_date_validation(repo, f$v$version_id, f$cfg$config_id)
    checks <- stats::setNames(out$mappings[[1]]$checks,
      vapply(out$mappings[[1]]$checks, function(x) x$rule_id, character(1)))
    expect_equal(checks[["TMP-01"]]$population_count, length(dates))
    expect_equal(checks[["TMP-01"]]$evaluated_count, length(dates))
    expect_equal(checks[["TMP-02"]]$population_count, sum(nzchar(dates)))
    expect_equal(checks[["TMP-02"]]$evaluated_count, sum(nzchar(dates)))
    expect_equal(checks[["TMP-08"]]$evaluated_count, length(dates))
  }
})
