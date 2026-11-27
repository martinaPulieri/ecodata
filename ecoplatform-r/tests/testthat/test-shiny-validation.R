test_that("Shiny runs the exact source selection and reads saved paginated results", {
  repo <- new_test_repo();f <- full_fixture(repo,full_archive())
  launch <- function(repo,operation_id){execute_validation_run(repo$root,operation_id,"module-test");list(operation_id=operation_id)}
  testthat::with_mocked_bindings({
    shiny::testServer(workspace_server,args=list(repo=repo),{
      session$setInputs(actor="tester",version=f$v$version_id,resource=f$v$resource_ids[1],config=f$cfg$config_id)
      session$flushReact()
      form <- validation$local$form
      expect_true(is.list(form))
      session$setInputs(validation_run=list(token=current_context()$token,request_id=form$request_id))
      id <- validation$local$active_operation
      expect_equal(state$validation_preferred,id)
      expect_equal(nrow(list_validation_runs(repo)),1)
      session$setInputs(validation_result=id,validation_detail="dates",validation_page=1,validation_page_size="1",validation_filter="")
      validation$refresh()
      expect_null(state$validation_preferred)
      expect_equal(validation$details()$total,2)
      expect_length(validation$details()$records,1)
      expect_match(output$validation_details,"2020-03-15")
      session$setInputs(validation_page=2)
      expect_match(output$validation_details,"03/04/2020")
      expect_match(output$history_table,"Validation")
      expect_match(output$validation_summary$html,"Recognised")
      expect_match(output$validation_summary$html,"not calendar")
      expect_equal(nrow(list_configurations(repo,f$v$version_id)),1)
    })
  },start_validation_worker=launch,.package="ecodata")
})

test_that("stale Shiny run buttons cannot submit another source or duplicate work", {
  repo <- new_test_repo();a <- full_fixture(repo,full_archive());b <- full_fixture(repo,full_archive())
  testthat::with_mocked_bindings({
    shiny::testServer(workspace_server,args=list(repo=repo),{
      session$setInputs(actor="tester",version=a$v$version_id,resource=a$v$resource_ids[1],config=a$cfg$config_id)
      old <- validation$local$form; oldtoken <- current_context()$token
      session$setInputs(version=b$v$version_id,resource=b$v$resource_ids[1],config=b$cfg$config_id)
      session$setInputs(validation_run=list(token=oldtoken,request_id=old$request_id))
      expect_equal(nrow(list_validation_runs(repo)),0)
      expect_match(state$notice,"context")
      form <- validation$local$form
      click <- list(token=current_context()$token,request_id=form$request_id)
      session$setInputs(validation_run=click)
      session$setInputs(validation_run=click)
      expect_equal(nrow(list_validation_runs(repo)),1)
      expect_equal(list_validation_runs(repo)$version_id,b$v$version_id)
    })
  },start_validation_worker=function(repo,operation_id)list(operation_id=operation_id),.package="ecodata")
})

test_that("removed-version result browsing stays available without authorising a new run", {
  repo <- new_test_repo();f <- full_fixture(repo,full_archive())
  op <- submit_validation_run(repo,f$v$version_id,f$cfg$config_id,"tester","historical-ui",0L)
  execute_validation_run(repo$root,op$operation_id,"worker")
  set_workspace_state(repo,f$v$version_id,"removed",0L,"removed-ui","tester")
  shiny::testServer(workspace_server,args=list(repo=repo),{
    session$setInputs(actor="tester",workspace_filter="removed",version=f$v$version_id,resource=f$v$resource_ids[1],config=f$cfg$config_id,
      validation_result=op$operation_id,validation_detail="dates",validation_page=1,validation_page_size="25",validation_filter="")
    expect_match(output$validation_details,"2020-03-15")
    expect_match(output$validation_panel$html,"Restore")
    session$setInputs(validation_run=list(token=current_context()$token,request_id=validation$local$form$request_id))
    expect_equal(nrow(list_validation_runs(repo)),1)
  })
})
