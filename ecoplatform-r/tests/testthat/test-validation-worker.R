test_that("queued cancellation is persistent and prevents a late worker from running", {
  repo <- new_test_repo(); f <- full_fixture(repo, full_archive())
  op <- submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","cancel-queued",0L)
  cancel_validation_run(repo,op$operation_id,"tester")
  execute_validation_run(repo$root,op$operation_id,"late-worker")
  expect_equal(get_validation_run(repo,op$operation_id)$status,"cancelled")
  expect_null(get_validation_result(repo,op$operation_id))
  expect_equal(nrow(get_validation_run(repo,op$operation_id)$claim),0)
  set_workspace_state(repo,f$v$version_id,"removed",0L,"after-cancel","tester")
  expect_equal(submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","cancel-queued",0L)$operation_id,op$operation_id)
})

test_that("a technical linkage failure does not suppress independent date results", {
  repo <- new_test_repo(); f <- full_fixture(repo, full_archive())
  op <- submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","independent",0L)
  testthat::with_mocked_bindings({
    execute_validation_run(repo$root,op$operation_id,"worker")
  },run_linkage_validation=function(...)stop("Injected linkage technical failure"),.package="ecodata")
  out <- get_validation_result(repo,op$operation_id)
  expect_equal(out$status,"completed_with_limitations")
  expect_equal(out$families$linkage$status,"failed")
  expect_equal(get_validation_summary(repo,op$operation_id)$date_counts$recognised,1)
  expect_equal(query_validation_details(repo,op$operation_id,"dates")$total,2)
  expect_true(any(get_validation_run(repo,op$operation_id)$progress$status=="failed"))
})

test_that("a real supervised worker persists results using its own connection", {
  repo <- new_test_repo(); f <- full_fixture(repo, full_archive())
  op <- submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","async",0L)
  started <- start_validation_worker(repo,op$operation_id)
  expect_equal(started$operation_id,op$operation_id)
  deadline <- proc.time()[["elapsed"]]+60
  repeat {
    refresh_validation_workers(repo)
    run <- get_validation_run(repo,op$operation_id)
    if(!run$status%in%c("queued","running"))break
    if(proc.time()[["elapsed"]]>deadline)stop("Validation worker did not finish")
    Sys.sleep(.05)
  }
  expect_equal(run$status,"completed_with_limitations",info=paste(utils::tail(run$events$reason,1),collapse="; "))
  expect_true(run$claim$pid!=Sys.getpid())
  expect_equal(query_validation_details(repo,op$operation_id,"dates")$total,2)
  expect_true(DBI::dbIsValid(repo$con))
  expect_equal(nrow(list_operations(repo)),1)
  expect_equal(nrow(list_configurations(repo,f$v$version_id)),1)
})
