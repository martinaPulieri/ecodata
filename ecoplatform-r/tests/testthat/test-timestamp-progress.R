test_that("timezone-unspecified timestamps infer their own format without assuming UTC", {
  expect_equal(infer_date_format(c("2009-06-29T00:00:00","2009-06-25T00:00:00"))$selected,"timestamp-no-zone")
  expect_equal(infer_date_format("2009-06-29T00:00:00Z")$selected,"timestamp-z")
  expect_null(infer_date_format(c("2009-06-29T00:00:00","2009-06-29T00:00:00Z"))$selected)
  expect_null(infer_date_format("2009-06-29T00:00:00+02:00")$selected)
})

test_that("a declared timestamp without timezone validates exactly and preserves source text", {
  repo<-new_test_repo()
  f<-full_fixture(repo,write_fixture(paste0("id,date\n1,2009-06-29T00:00:00\n",
    "2,2009-06-29T00:00:00Z\n3,2009-06-29\n4,2009-06-29T00:00:00+02:00\n5, 2009-06-29T00:00:00\n")))
  r<-prepare_date_information(repo,f$v$version_id,f$cfg$config_id)
  cfg<-save_date_declarations(repo,r,list(list(table_id=r$preparation$tables[[1]]$table_id,
    columns=c(value=1),pattern_id="timestamp-no-zone")),"tester")
  out<-run_date_validation(repo,f$v$version_id,cfg$config_id)
  expect_equal(out$engine_version,"lexical-dates-1.1")
  rows<-out$mappings[[1]]$rows
  expect_equal(vapply(rows,`[[`,character(1),"status"),c("recognised",rep("unrecognised",4)))
  expect_equal(rows[[1]]$original_values$value,"2009-06-29T00:00:00")
  expect_equal(rows[[1]]$candidates[[1]]$pattern$timezone,"unspecified")
  expect_equal(cfg$validation_spec$patterns$version,"date-patterns-1.2")
  expect_true(verify_input(repo,f$v$version_id)$ok)
  expect_false("timestamp-no-zone"%in%names(date_patterns("date-patterns-1.0")$patterns))
  expect_false("timestamp-no-zone"%in%names(date_patterns("date-patterns-0.1")$patterns))
  expect_error(new_validation_spec(cfg$validation_spec$date_mappings,pattern_version="date-patterns-1.0"),
    "absent from the selected catalogue")
})

test_that("the Validation panel displays activity for a queued run and hides it after cancellation", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  testthat::with_mocked_bindings({
    shiny::testServer(workspace_server,args=list(repo=repo),{
      session$setInputs(actor="tester",version=f$v$version_id,resource=f$v$resource_ids[1],config=f$cfg$config_id)
      form<-validation$local$form
      session$setInputs(validation_run=list(token=current_context()$token,request_id=form$request_id))
      expect_match(output$validation_panel$html,'aria-label="Validation progress"',fixed=TRUE)
      id<-validation$local$active_operation
      session$setInputs(validation_cancel=list(token=current_context()$token,operation_id=id))
      expect_equal(get_validation_run(repo,id)$status,"cancelled")
      expect_false(grepl('role="progressbar"',output$validation_panel$html,fixed=TRUE))
    })
  },start_validation_worker=function(...)NULL,.package="ecodata")
})

test_that("validation shows indeterminate activity only for pending work", {
  for(status in c("queued","running")) {
    run<-list(status=status,progress=data.frame(family="dates",status=status,message="Reading configured dates"))
    html<-as.character(validation_activity_indicator(run))
    expect_match(html,'role="progressbar"',fixed=TRUE)
    expect_match(html,"Reading configured dates",fixed=TRUE)
    expect_false(grepl("aria-valuenow",html,fixed=TRUE))
  }
  for(status in c("completed","completed_with_limitations","failed","interrupted","cancelled"))
    expect_null(validation_activity_indicator(list(status=status)))
})
