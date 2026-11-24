test_that("browser upload names survive Shiny temporary paths and inspection", {
  repo <- new_test_repo()
  path <- tempfile() # no extension: Shiny datapath must not become the filename
  writeBin(charToRaw("id,value\n001,NA\n"), path)
  upload <- data.frame(name = "ecologia.csv", size = file.info(path)$size, type = "text/csv", datapath = path)
  result <- register_uploaded_inputs(repo, upload, "Ecologia", "revisore")
  expect_equal(get_input(repo, result$version_id)$resources$original_name, "ecologia.csv")
  unlink(path)
  observed <- run_workspace_inspection(repo, result$version_id, result$config_id, "revisore")
  expect_equal(observed$inspection$resources[[1]]$status, "ready")
  expect_identical(observed$inspection$resources[[1]]$tables[[1]]$preview[[1]], "001")
  expect_equal(list_operations(repo)$status, "completed")
})

test_that("invalid browser uploads fail before manifest registration", {
  repo <- new_test_repo()
  path <- write_fixture()
  upload <- data.frame(name = "../bad.csv", size = file.info(path)$size, type = "text/csv", datapath = path)
  expect_error(register_uploaded_inputs(repo, upload, "Test", "tester"), "filename")
  upload$name <- "good.csv"
  upload$size <- 9999
  expect_error(register_uploaded_inputs(repo, upload, "Test", "tester"), "size")
  expect_equal(nrow(list_inputs(repo)), 0)
})

test_that("failed inspections are logged against the frozen configuration", {
  repo <- new_test_repo()
  v <- register_input(write_fixture("bad", ".pdf"), list(), repo)
  cfg <- make_config(repo, v$version_id)
  result <- run_workspace_inspection(repo, v$version_id, cfg$config_id, "tester")
  expect_equal(list_operations(repo)$status, "completed_with_limitations")
  expect_equal(result$inspection$resources[[1]]$status, "unsupported")
  expect_equal(get_operation(repo, result$operation_id)$configuration$config_id, cfg$config_id)
})
