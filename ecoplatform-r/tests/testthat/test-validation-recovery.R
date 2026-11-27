test_that("a stopped claimed worker is recoverable but an active session is not interrupted", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  op<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","alive",0L)
  expect_true(claim_validation_run(repo,op$operation_id,"live-token"))
  other<-open_repository(repo$root);withr::defer(close_repository(other))
  expect_equal(get_validation_run(other,op$operation_id)$status,"running")
  expect_error(recover_validation_run(other,op$operation_id,"tester"),"still active")
  expect_false(claim_validation_run(other,op$operation_id,"duplicate-token"))
  dead<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","dead",0L)
  path<-getNamespaceInfo(asNamespace("ecodata"),"path")
  callr::r(function(root,id,path){
    if(file.exists(file.path(path,"R","service_validation.R")))pkgload::load_all(path,quiet=TRUE) else library(ecodata)
    r<-ecodata::open_repository(root);on.exit(ecodata::close_repository(r))
    get("claim_validation_run",asNamespace("ecodata"))(r,id,"dead-token")
  },args=list(repo$root,dead$operation_id,path),libpath=.libPaths(),
    env=c(callr::rcmd_safe_env(),LANG="en_US.UTF-8",LC_ALL=if(.Platform$OS.type=="windows")"English_United States.utf8" else "C.UTF-8"))
  recovered<-recover_validation_run(repo,dead$operation_id,"tester")
  expect_equal(recovered$status,"interrupted")
  expect_null(get_validation_result(repo,dead$operation_id))
})

test_that("a failed result insert rolls back every result and records a technical failure", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  op<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","disk-failure",0L)
  DBI::dbExecute(repo$con,"CREATE TRIGGER reject_validation_rows BEFORE INSERT ON validation_rows BEGIN SELECT RAISE(ABORT,'synthetic write failure'); END")
  execute_validation_run(repo$root,op$operation_id,"worker")
  expect_equal(get_validation_run(repo,op$operation_id)$status,"failed")
  expect_null(get_validation_result(repo,op$operation_id))
  expect_equal(DBI::dbGetQuery(repo$con,"SELECT count(*) AS n FROM validation_mappings")$n,0)
  expect_equal(DBI::dbGetQuery(repo$con,"SELECT count(*) AS n FROM validation_rows")$n,0)
})

test_that("cancellation arriving at finalisation saves no partial scientific results", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  op<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","cancel-final",0L)
  persist<-persist_validation_result
  testthat::with_mocked_bindings({execute_validation_run(repo$root,op$operation_id,"worker")},
    persist_validation_result=function(repo,operation_id,token,result){
      cancel_validation_run(repo,operation_id,"tester");persist(repo,operation_id,token,result)
    },.package="ecodata")
  expect_equal(get_validation_run(repo,op$operation_id)$status,"cancelled")
  expect_equal(query_validation_details(repo,op$operation_id,"dates")$total,0)
  expect_equal(query_validation_details(repo,op$operation_id,"linkage")$total,0)
})

test_that("a run rejects application code changes after its request was frozen", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  op<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","code-change",0L)
  testthat::with_mocked_bindings({execute_validation_run(repo$root,op$operation_id,"worker")},
    validation_code_fingerprint=function()hash_text("different code"),.package="ecodata")
  expect_equal(get_validation_run(repo,op$operation_id)$status,"failed")
  expect_null(get_validation_result(repo,op$operation_id))
  expect_match(utils::tail(get_validation_run(repo,op$operation_id)$events$reason,1),"code")
})

test_that("application code fingerprints are independent of process collation", {
  a<-withr::with_collate("C",validation_code_fingerprint())
  b<-withr::with_collate(if(.Platform$OS.type=="windows")"English_United States.utf8" else "C.UTF-8",validation_code_fingerprint())
  expect_equal(a,b)
})
