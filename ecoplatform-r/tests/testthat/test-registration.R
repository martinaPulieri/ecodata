test_that("registration preserves bytes and survives source deletion and restart", {
  repo <- new_test_repo()
  path <- write_fixture()
  expected <- readBin(path, "raw", n = file.info(path)$size)
  result <- register_input(path, list(title = "Synthetic", licence = "unknown"), repo)
  resource <- get_input(repo, result$version_id)$resources
  expect_identical(readBin(resource$owned_path, "raw", n = length(expected)), expected)
  expect_equal(resource$acquisition_status, "unknown")
  expect_equal(resource$integrity_status, "verified")
  unlink(path)
  root <- repo$root
  close_repository(repo)
  reopened <- open_repository(root)
  withr::defer(close_repository(reopened))
  expect_equal(get_input(reopened, result$version_id)$metadata$title, "Synthetic")
  expect_equal(verify_input(reopened, result$version_id)$ok, TRUE)
})

test_that("identical filenames and bytes still receive distinct resource identities", {
  repo <- new_test_repo()
  path <- write_fixture()
  one <- register_input(c(path, path), list(), repo)
  resources <- get_input(repo, one$version_id)$resources
  expect_equal(nrow(resources), 2L)
  expect_equal(length(unique(resources$resource_id)), 2L)
  expect_equal(length(unique(resources$sha256)), 1L)
  expect_equal(length(unique(resources$owned_path)), 2L)
})

test_that("registration rejects missing inputs atomically and retains unsupported bytes", {
  repo <- new_test_repo()
  path <- write_fixture()
  expect_error(register_input(c(path, paste0(path, "missing")), list(), repo), "regular file")
  expect_equal(nrow(list_inputs(repo)), 0L)
  expect_length(list.files(file.path(repo$root, "inputs")), 0L)
  other <- write_fixture("not a supported table", ".pdf")
  v <- register_input(other, list(), repo)
  cfg <- make_config(repo, v$version_id)
  inspection <- inspect_input(v$version_id, cfg$config_id, repo)
  expect_equal(inspection$resources[[1]]$status, "unsupported")
  expect_true(verify_input(repo, v$version_id)$ok)
})

test_that("tampering is detected before inspection or operation submission", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  cfg <- make_config(repo, v$version_id)
  owned <- get_input(repo, v$version_id)$resources$owned_path
  Sys.chmod(owned, "0666")
  writeBin(charToRaw("changed"), owned)
  expect_false(verify_input(repo, v$version_id)$ok)
  expect_error(inspect_input(v$version_id, cfg$config_id, repo), "integrity")
  expect_error(submit_operation(repo, v$version_id, cfg$config_id, "inspect", "tampered", "tester"), "integrity")
})

test_that("source versions retain explicit parent lineage and acquisition evidence", {
  repo <- new_test_repo()
  first <- register_fixture(repo)
  next_version <- register_input(write_fixture("id\n3\n"), list(reason = "new delivery"), repo,
    parent_version_id = first$version_id, acquisition_status = "incomplete")
  expect_equal(get_input(repo, next_version$version_id)$version$parent_version_id, first$version_id)
  expect_equal(get_input(repo, next_version$version_id)$version$dataset_id, first$dataset_id)
  expect_equal(get_input(repo, next_version$version_id)$resources$acquisition_status, "incomplete")
  expect_true(verify_input(repo, first$version_id)$ok)
})

test_that("a database failure cleans newly owned copies without deleting prior inputs", {
  repo <- new_test_repo()
  prior <- register_fixture(repo)
  DBI::dbExecute(repo$con, "CREATE TRIGGER reject_resource BEFORE INSERT ON resources BEGIN SELECT RAISE(ABORT, 'forced registration failure'); END")
  before <- list.files(file.path(repo$root, "inputs"))
  expect_error(register_fixture(repo), "forced registration failure")
  expect_equal(list.files(file.path(repo$root, "inputs")), before)
  expect_equal(nrow(list_inputs(repo)), 1L)
  expect_true(verify_input(repo, prior$version_id)$ok)
})
