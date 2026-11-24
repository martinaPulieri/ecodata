test_that("registration quotas are enforced before copying and originals are untouched", {
  repo <- new_test_repo()
  path <- write_fixture("id\n123\n")
  before <- readBin(path, "raw", n = 100)
  expect_error(register_input(path, list(), repo, max_file_bytes = 2), "limit")
  expect_error(register_input(c(path, path), list(), repo, max_total_bytes = 10), "limit")
  expect_length(list.files(file.path(repo$root, "inputs")), 0)
  expect_identical(readBin(path, "raw", n = 100), before)
  expect_error(register_input(path, list(), repo, acquisition_status = "assumed"), "acquisition_status")
})

test_that("quoted delimiters and multiline values retain lexical content", {
  repo <- new_test_repo()
  v <- register_input(write_fixture('id,note\n001,"a,b"\n002,"line1\nline2"'), list(), repo)
  cfg <- make_config(repo, v$version_id)
  table <- inspect_input(v$version_id, cfg$config_id, repo)$resources[[1]]$tables[[1]]
  expect_identical(table$preview[[2]], c("a,b", "line1\nline2"))
  expect_identical(table$columns, c("id", "note"))
})

test_that("runtime storage rejects known synchronised and network paths", {
  expect_error(open_repository(file.path(tempdir(), "Dropbox", "runtime")), "non-synchronised")
  expect_error(open_repository("//server/share/ecodata"), "non-synchronised")
})

test_that("versioned manifest rows cannot be amended or removed through SQL", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  for (table in c("datasets", "dataset_versions", "resources")) {
    expect_error(DBI::dbExecute(repo$con, paste("DELETE FROM", table)), "immutable")
  }
  expect_true(verify_input(repo, v$version_id)$ok)
})

test_that("operation completion and reruns preserve earlier snapshots and events", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  cfg <- make_config(repo, v$version_id)
  one <- submit_operation(repo, v$version_id, cfg$config_id, "inspect", "first", "tester")
  record_operation_event(repo, one$operation_id, "running", "tester")
  record_operation_event(repo, one$operation_id, "completed", "tester", "inspection recorded by worker")
  two <- submit_operation(repo, v$version_id, cfg$config_id, "inspect", "rerun", "tester")
  expect_false(identical(one$operation_id, two$operation_id))
  expect_equal(get_operation(repo, one$operation_id)$events$status, c("queued", "running", "completed"))
  expect_equal(list_operations(repo)$status, c("completed", "queued"))
  expect_error(backup_repository(repo, repo$db_path), "already exists")
})
