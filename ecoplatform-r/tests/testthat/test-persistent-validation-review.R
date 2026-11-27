test_that("queuing validation reads saved manifests without hashing source bytes", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  owned<-get_input(repo,f$v$version_id)$resources$owned_path
  hash<-hash_file
  testthat::with_mocked_bindings({
    op<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","nonblocking-submit",0L)
    expect_equal(get_validation_run(repo,op$operation_id)$status,"queued")
  },verify_input=function(...)stop("Source byte verification ran in submission"),
    hash_file=function(path){if(path%in%owned)stop("Source bytes hashed in submission");hash(path)},.package="ecodata")
})

test_that("source changes at finalisation clear classifications and final progress consistently", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  op<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","final-source-change",0L)
  persist<-persist_validation_result
  testthat::with_mocked_bindings({execute_validation_run(repo$root,op$operation_id,"worker")},
    persist_validation_result=function(repo,operation_id,token,result){
      writeBin(charToRaw("changed"),get_input(repo,f$v$version_id)$resources$owned_path)
      persist(repo,operation_id,token,result)
    },.package="ecodata")
  out<-get_validation_result(repo,op$operation_id)
  expect_equal(query_validation_details(repo,op$operation_id,"dates")$total,0)
  expect_true(all(vapply(out$families$dates$mappings,function(m)sum(unlist(m$pattern_counts))==0,logical(1))))
  p<-get_validation_run(repo,op$operation_id)$progress
  p<-p[!duplicated(p$family,fromLast=TRUE),,drop=FALSE]
  expect_equal(p$status[p$family=="dates"],out$families$dates$status)
  expect_equal(p$status[p$family=="linkage"],out$families$linkage$status)
})

test_that("Validation follows pending work from another session while Results stays historical", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  old<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","old-session-run",0L)
  cancel_validation_run(repo,old$operation_id,"tester")
  shiny::testServer(workspace_server,args=list(repo=repo),{
    session$setInputs(actor="tester",version=f$v$version_id,resource=f$v$resource_ids[1],config=f$cfg$config_id,validation_result=old$operation_id)
    other<-open_repository(repo$root)
    newer<-submit_validation_run(other,f$v$version_id,f$cfg$config_id,"tester","other-session-run",0L)
    close_repository(other)
    validation$refresh()
    session$flushReact()
    expect_equal(validation$local$active_operation,newer$operation_id)
    expect_match(output$validation_panel$html,"Validation in progress")
    expect_match(output$validation_panel$html,"Cancel run")
    expect_equal(validation$summary()$run$operation_id,old$operation_id)
  })
})

test_that("managed validation lifecycle cannot be advanced by the generic audit API", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  op<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","owned",0L)
  claim_validation_run(repo,op$operation_id,"owner")
  expect_error(record_operation_event(repo,op$operation_id,"completed","generic-audit"),"owning worker")
  expect_equal(get_validation_run(repo,op$operation_id)$status,"running")
  expect_error(set_workspace_state(repo,f$v$version_id,"removed",0L,"blocked-owner","tester"),"queued or running")
})

test_that("generic validation submission creates a frozen managed run", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  op<-submit_operation(repo,f$v$version_id,f$cfg$config_id,"validation","generic-validation","tester")
  expect_equal(nrow(list_validation_runs(repo)),1)
  expect_equal(get_validation_run(repo,op$operation_id)$frozen$config_id,f$cfg$config_id)
})

test_that("pre-v3 validation intent can be explicitly cancelled without inventing a snapshot", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  op<-with_write(repo$con,function()submit_operation_locked(repo,f$v$version_id,f$cfg$config_id,"validation","legacy-intent","tester"))
  expect_equal(nrow(list_validation_runs(repo)),0)
  cancel_validation_run(repo,op$operation_id,"tester")
  expect_equal(utils::tail(get_operation(repo,op$operation_id)$events$status,1),"cancelled")
  expect_equal(nrow(list_validation_runs(repo)),0)
  expect_silent(set_workspace_state(repo,f$v$version_id,"removed",0L,"after-legacy","tester"))
})

test_that("source changes during batch preparation cannot publish old classifications", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  op<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","batch-source-race",0L)
  prepare<-prepare_validation_batches;changed<-FALSE
  testthat::with_mocked_bindings({execute_validation_run(repo$root,op$operation_id,"worker")},
    prepare_validation_batches=function(result){
      batches<-prepare(result)
      if(!changed){changed<<-TRUE;writeBin(charToRaw("changed"),get_input(repo,f$v$version_id)$resources$owned_path)}
      batches
    },.package="ecodata")
  expect_equal(query_validation_details(repo,op$operation_id,"dates")$total,0)
  expect_equal(query_validation_details(repo,op$operation_id,"linkage")$total,0)
})

test_that("normalised records bulk append once per table and summaries omit per-key details", {
  repo<-new_test_repo();f<-linkage_engine_fixture(repo)
  op<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","bulk",0L)
  append<-DBI::dbAppendTable;calls<-list()
  testthat::with_mocked_bindings({execute_validation_run(repo$root,op$operation_id,"worker")},
    dbAppendTable=function(conn,name,value,...){calls[[name]]<<-if(is.null(calls[[name]]))1L else calls[[name]]+1L;append(conn,name,value,...)},.package="DBI")
  expect_equal(get_validation_run(repo,op$operation_id)$status,"completed_with_limitations")
  expect_equal(calls$validation_finding_targets,1L)
  expect_equal(calls$validation_findings,1L)
  expect_equal(calls$validation_checks,1L)
  expect_equal(calls$validation_rows,1L)
  summary<-get_validation_summary(repo,op$operation_id)
  link<-Filter(function(m)m$family=="linkage",summary$mappings)[[1]]
  expect_null(link$multiplicity$per_unique_key)
  expect_true(length(get_validation_result(repo,op$operation_id)$families$linkage$mappings[[1]]$multiplicity$per_unique_key)>0)
})

test_that("a failed competing launcher cannot fail another worker's active claim", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  op<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","launcher-race",0L)
  testthat::with_mocked_bindings({
    expect_error(start_validation_worker(repo,op$operation_id),"synthetic launch failure")
  },r_bg=function(...){claim_validation_run(repo,op$operation_id,"other-owner");stop("synthetic launch failure")},.package="callr")
  run<-get_validation_run(repo,op$operation_id)
  expect_equal(run$status,"running")
  expect_equal(run$claim$worker_token,"other-owner")
})

test_that("all technical family failures remain failed even if source integrity also fails", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  op<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","failed-precedence",0L)
  testthat::with_mocked_bindings({execute_validation_run(repo$root,op$operation_id,"worker")},
    run_linkage_validation=function(...)stop("linkage technical failure"),
    run_date_validation=function(repo,...){writeBin(charToRaw("changed"),get_input(repo,f$v$version_id)$resources$owned_path);stop("date technical failure")},.package="ecodata")
  expect_equal(get_validation_run(repo,op$operation_id)$status,"failed")
  expect_equal(get_validation_result(repo,op$operation_id)$status,"failed")
})

test_that("code is checked again after batch preparation", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  op<-submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","batch-code-race",0L)
  prepare<-prepare_validation_batches;fingerprint<-validation_code_fingerprint;changed<-FALSE
  testthat::with_mocked_bindings({execute_validation_run(repo$root,op$operation_id,"worker")},
    prepare_validation_batches=function(result){x<-prepare(result);changed<<-TRUE;x},
    validation_code_fingerprint=function(){if(changed)hash_text("changed") else fingerprint()},.package="ecodata")
  expect_equal(get_validation_run(repo,op$operation_id)$status,"failed")
  expect_null(get_validation_result(repo,op$operation_id))
})
