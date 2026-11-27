test_that("declared formats reject other recognised patterns and preserve originals", {
  repo <- new_test_repo()
  f <- full_fixture(repo, write_fixture("date\n15/03/2020\n2020-03-15\n30/02/2020\n 15/03/2020 \n"))
  request <- prepare_date_information(repo, f$v$version_id, f$cfg$config_id)
  table <- request$preparation$tables[[1]]
  saved <- save_date_declarations(repo, request, list(list(table_id=table$table_id,
    columns=c(value=0L), pattern_id="dmy-slash")), "tester")
  out <- run_date_validation(repo, f$v$version_id, saved$config_id)
  rows <- out$mappings[[1]]$rows
  expect_equal(vapply(rows, `[[`, character(1), "status"),
    c("recognised","unrecognised","recognised","unrecognised"))
  expect_equal(rows[[4]]$original_values$value, " 15/03/2020 ")
  expect_equal(saved$validation_spec$date_mappings[[1]]$declared_pattern, "dmy-slash")
  expect_equal(nrow(list_configurations(repo,f$v$version_id)),2L)
  expect_error(save_date_declarations(repo,request,list(list(table_id=table$table_id,
    columns=c(value=0L),pattern_id="ymd-dash")),"tester"),"stale")
})

test_that("date inference distinguishes evidence from ambiguous and mixed fields", {
  expect_equal(infer_date_format(c("15/03/2020","03/04/2020"))$selected,"dmy-slash")
  expect_equal(infer_date_format(c("03/15/2020","03/04/2020"))$selected,"mdy-slash")
  expect_null(infer_date_format(c("03/04/2020","05/06/2020"))$selected)
  expect_null(infer_date_format(c("2020-03-15","15/03/2020"))$selected)
  expect_null(infer_date_format(c(""," "))$selected)
  expect_equal(infer_date_format(c("2020-03-15","2020-04-05"))$selected,"ymd-dash")
})

test_that("save and preview uses the new revision without a second click", {
  repo<-new_test_repo();f<-full_fixture(repo,write_fixture("id;date\n001;2020-03-15\n"))
  shiny::testServer(workspace_server,args=list(repo=repo),{
    session$setInputs(actor="tester",version=f$v$version_id,resource=f$v$resource_ids[1],config=f$cfg$config_id)
    session$setInputs(form_context=current_context()$token,delimiter=";",encoding="UTF-8",decimal_mark=".",quote='"',save=1)
    latest<-utils::tail(list_configurations(repo,f$v$version_id)$config_id,1)
    expect_false(is.null(state$inspection))
    expect_equal(state$inspection$config_id,latest)
    session$setInputs(config=latest)
    expect_false(is.null(state$inspection))
    expect_match(output$preview_table,"001")
    expect_equal(nrow(list_operations(repo)),1L)
  })
})

test_that("Next prepares in a real background process and Run saves an override for dates only", {
  repo<-new_test_repo();f<-full_fixture(repo,write_fixture("id,date\n001,15/03/2020\n002,2020-03-15\n"))
  launch<-function(repo,operation_id){execute_validation_run(repo$root,operation_id,"date-flow-test")}
  testthat::with_mocked_bindings({
    shiny::testServer(workspace_server,args=list(repo=repo),{
      session$setInputs(actor="tester",version=f$v$version_id,resource=f$v$resource_ids[1],config=f$cfg$config_id)
      session$setInputs(form_context=current_context()$token,inspect=1)
      click<-list(token=current_context()$token)
      session$setInputs(date_next=click)
      expect_equal(date_information$local$status,"checking")
      expect_equal(nrow(list_configurations(repo,f$v$version_id)),1L)
      date_information$local$process$wait(timeout=60000)
      date_information$poll();session$flushReact()
      expect_equal(date_information$local$status,"ready")
      expect_match(output$date_information_panel$html,"Date field")
      expect_false(grepl("Date role|Reason / evidence",output$date_information_panel$html))
      session$setInputs(info_structure_1="single",info_fields_1="1")
      do.call(session$setInputs,stats::setNames(list("ymd-dash"),date_information$format_id(1,1)))
      session$setInputs(info_fields_1=c("0","1"))
      controls<-xml2::read_html(output$info_formats_1$html)
      chosen<-xml2::xml_text(xml2::xml_find_all(controls,paste0("//select[@id='",session$ns(date_information$format_id(1,1)),"']/option[@selected]")))
      expect_equal(chosen,"YYYY-MM-DD")
      session$setInputs(info_fields_1="1")
      run_click<-list(token=current_context()$token,request_id=date_information$local$request_id)
      session$setInputs(date_run=run_click)
      id<-date_information$local$operation
      expect_false(is.null(id))
      run<-get_validation_run(repo,id)
      expect_equal(unlist(run$request$families),"dates")
      out<-get_validation_result(repo,id)
      expect_null(out$families$linkage)
      rows<-query_validation_details(repo,id,"dates")$records
      expect_equal(rows[[1]]$status,"unrecognised")
      expect_equal(rows[[2]]$status,"recognised")
      session$setInputs(date_run=run_click)
      expect_equal(nrow(list_validation_runs(repo)),1L)
      expect_equal(nrow(list_configurations(repo,f$v$version_id)),2L)
      expect_true(all(verify_input(repo,f$v$version_id)$resources$ok))
    })
  },start_validation_worker=launch,.package="ecodata")
})

test_that("a replacement field selection excludes deselected and descriptor dates", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  r<-prepare_date_information(repo,f$v$version_id,f$cfg$config_id)
  tid<-r$preparation$tables[[1]]$table_id
  a<-save_date_declarations(repo,r,list(list(table_id=tid,columns=c(value=2),pattern_id="ymd-dash")),"tester")
  r<-prepare_date_information(repo,f$v$version_id,a$config_id)
  b<-save_date_declarations(repo,r,list(list(table_id=tid,columns=c(value=1),pattern_id="year")),"tester")
  out<-run_date_validation(repo,f$v$version_id,b$config_id)
  expect_equal(length(out$mappings),1L)
  expect_equal(out$mappings[[1]]$context$validation_spec$date_mappings[[1]]$columns$value$position,1)
  expect_equal(length(get_configuration(repo,a$config_id)$validation_spec$date_mappings),1L)
})

test_that("a format override cannot leak into the same column position in another file", {
  repo<-new_test_repo()
  a<-full_fixture(repo,write_fixture("id,date\n001,2020-03-15\n"))
  b<-full_fixture(repo,write_fixture("id,date\n001,15/03/2020\n"))
  immediate_worker<-function(repo,context){
    result<-prepare_date_information(repo,context$version_id,context$config$config_id,context$workspace_revision)
    list(is_alive=function()FALSE,get_result=function()result,kill=function()NULL)
  }
  testthat::with_mocked_bindings({
    shiny::testServer(workspace_server,args=list(repo=repo),{
      for(f in list(a,b)) {
        session$setInputs(actor="tester",version=f$v$version_id,resource=f$v$resource_ids[1],config=f$cfg$config_id)
        session$setInputs(form_context=current_context()$token,inspect=1)
        session$setInputs(date_next=list(token=current_context()$token))
        date_information$poll();session$flushReact()
        session$setInputs(info_structure_1="single",info_fields_1="1")
        controls<-xml2::read_html(output$info_formats_1$html)
        chosen<-xml2::xml_text(xml2::xml_find_all(controls,paste0("//select[@id='",session$ns(date_information$format_id(1,1)),"']/option[@selected]")))
        expect_equal(chosen,if(identical(f$v$version_id,a$v$version_id))"YYYY-MM-DD" else "DD/MM/YYYY")
        do.call(session$setInputs,stats::setNames(list("mdy-slash"),date_information$format_id(1,1)))
      }
    })
  },start_date_information_worker=immediate_worker,.package="ecodata")
})

test_that("an information-worker launch failure leaves a retryable error instead of progress", {
  repo<-new_test_repo();f<-full_fixture(repo,write_fixture("date\n2020-03-15\n"))
  testthat::with_mocked_bindings({
    shiny::testServer(workspace_server,args=list(repo=repo),{
      session$setInputs(actor="tester",version=f$v$version_id,resource=f$v$resource_ids[1],config=f$cfg$config_id)
      session$setInputs(form_context=current_context()$token,inspect=1)
      session$setInputs(date_next=list(token=current_context()$token))
      expect_equal(date_information$local$status,"failed")
      expect_match(output$date_information_panel$html,"Injected launch failure")
      expect_false(grepl('disabled="disabled"',output$date_next$html,fixed=TRUE))
    })
  },start_date_information_worker=function(...)stop("Injected launch failure"),.package="ecodata")
})

test_that("multiple date fields and split components keep distinct declared formats", {
  repo<-new_test_repo();f<-full_fixture(repo,write_fixture("first,second,day,month,year\n2020-03-15,15/03/2020,7,03,2020\n"))
  request<-prepare_date_information(repo,f$v$version_id,f$cfg$config_id)
  tid<-request$preparation$tables[[1]]$table_id
  cfg<-save_date_declarations(repo,request,list(
    list(table_id=tid,columns=c(value=0),pattern_id="ymd-dash"),
    list(table_id=tid,columns=c(value=1),pattern_id="dmy-slash"),
    list(table_id=tid,columns=c(day=2,month=3,year=4),pattern_id="split-numeric")),"tester")
  out<-run_date_validation(repo,f$v$version_id,cfg$config_id)
  expect_equal(length(out$mappings),3L)
  expect_equal(vapply(out$mappings,function(m)m$rows[[1]]$status,character(1)),rep("recognised",3))
  expect_error(save_date_declarations(repo,prepare_date_information(repo,f$v$version_id,cfg$config_id),
    list(list(table_id=tid,columns=c(value=0),pattern_id="unsupported")),"tester"),"declared date format")
})
