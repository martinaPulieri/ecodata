test_that("configurations append immutable snapshots with optimistic concurrency", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  first <- make_config(repo, v$version_id, metadata = list(coverage = "unknown"))
  second <- make_config(repo, v$version_id, expected_revision = 1L, metadata = list(coverage = "2010"))
  expect_equal(first$revision, 1L)
  expect_equal(second$revision, 2L)
  expect_equal(get_configuration(repo, first$config_id)$metadata$coverage, "unknown")
  expect_equal(get_configuration(repo, second$config_id)$metadata$coverage, "2010")
  expect_error(make_config(repo, v$version_id, expected_revision = 1L), "stale")
  expect_error(DBI::dbExecute(repo$con, "UPDATE configuration_revisions SET actor_id = 'other'"), "immutable")
  expect_error(DBI::dbExecute(repo$con, "DELETE FROM configuration_revisions"), "immutable")
  expect_equal(nrow(list_configurations(repo, v$version_id)), 2L)
})

test_that("configuration binds known resources and rejects invalid parser settings", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  resource <- get_input(repo, v$version_id)$resources$resource_id
  parsers <- setNames(list(list(delimiter = ";", encoding = "UTF-8", decimal_mark = ",", quote = '"')), resource)
  cfg <- make_config(repo, v$version_id, parsers = parsers)
  expect_equal(get_configuration(repo, cfg$config_id)$parsers[[resource]]$delimiter, ";")
  parsers[[resource]]$delimiter <- "many"
  expect_error(make_config(repo, v$version_id, parsers = parsers, expected_revision = 1L), "delimiter")
  expect_error(make_config(repo, v$version_id, parsers = list(unknown = list())), "resource")
})

test_that("schema confirmation requires evidence and never changes earlier configurations", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  initial <- make_config(repo, v$version_id)
  expect_false(get_configuration(repo, initial$config_id)$schema$confirmed)
  expect_error(confirm_profile(v$version_id, "dwc_occurrence", "", 1L, repo, "tester"), "evidence")
  confirmed <- confirm_profile(v$version_id, "dwc_occurrence", "Publisher metadata declares Occurrence", 1L, repo, "tester")
  expect_true(get_configuration(repo, confirmed$config_id)$schema$confirmed)
  expect_false(get_configuration(repo, initial$config_id)$schema$confirmed)
  expect_error(confirm_profile(v$version_id, "invented", "Evidence", 2L, repo, "tester"), "supported")
})

test_that("separate connections cannot silently overwrite a configuration revision", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  other <- open_repository(repo$root)
  withr::defer(close_repository(other))
  make_config(repo, v$version_id)
  expect_error(make_config(other, v$version_id), "stale")
  expect_equal(nrow(list_configurations(other, v$version_id)), 1L)
})
