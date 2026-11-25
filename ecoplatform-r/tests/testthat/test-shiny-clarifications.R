test_that("Shiny drafts, cancel and explicit approval are separate actions", {
  repo<-new_test_repo();f<-full_fixture(repo,write_fixture("date,value\n03/04/2020,NA\n"))
  rid<-f$v$resource_ids[1]
  shiny::testServer(workspace_server,args=list(repo=repo),{
    session$setInputs(actor="alice",version=f$v$version_id,resource=rid,config=f$cfg$config_id)
    session$setInputs(form_context=current_context()$token,clarify_load=1)
    expect_true(length(clarification$state$request$questions)>0L)
    q<-Filter(function(q)q$type=="date_mapping",clarification$state$request$questions)[[1]]
    session$setInputs(clarify_question=q$question_id,clarify_role="sampling_date",
      clarify_mode="single",clarify_value="0",clarify_order="",clarify_evidence="Owner confirmed role")
    session$setInputs(clarify_review=1)
    expect_false(is.null(clarification$state$draft))
    expect_equal(nrow(list_configurations(repo,f$v$version_id)),1L)
    session$setInputs(clarify_cancel=1)
    expect_null(clarification$state$draft)
    expect_equal(nrow(list_configurations(repo,f$v$version_id)),1L)
    session$setInputs(clarify_review=2)
    # Approve the displayed server draft, not changed controls underneath it.
    session$setInputs(clarify_role="changed-after-review",clarify_approve=1)
    saved<-get_configuration(repo,utils::tail(list_configurations(repo,f$v$version_id)$config_id,1))
    expect_equal(saved$revision,2L)
    expect_equal(saved$validation_spec$date_mappings[[1]]$date_role,"sampling_date")
    expect_null(clarification$state$draft)
    session$setInputs(config=saved$config_id)
    expect_match(as.character(output$clarification_history),"alice")
    expect_match(as.character(output$clarification_history),"sampling_date")
    expect_match(as.character(output$clarification_history),"Owner confirmed role")
  })
})

test_that("Shiny cannot approve a draft after switching context or operator", {
  repo<-new_test_repo()
  f<-full_fixture(repo,write_fixture("date\n2020\n"))
  other<-full_fixture(repo,write_fixture("date\n2021\n"))
  shiny::testServer(workspace_server,args=list(repo=repo),{
    session$setInputs(actor="alice",version=f$v$version_id,resource=f$v$resource_ids[1],config=f$cfg$config_id)
    session$setInputs(form_context=current_context()$token,clarify_load=1)
    q<-clarification$state$request$questions[[1]]
    session$setInputs(clarify_question=q$question_id,clarify_role="sampling_date",
      clarify_mode="single",clarify_value="0",clarify_order="",clarify_evidence="Owner")
    session$setInputs(clarify_review=1)
    session$setInputs(actor="bob",clarify_approve=1)
    expect_equal(nrow(list_configurations(repo,f$v$version_id)),1L)
    expect_match(state$notice,"operatore|operator")
    session$setInputs(version=other$v$version_id,resource=other$v$resource_ids[1],config=other$cfg$config_id)
    session$setInputs(form_context=current_context()$token,clarify_approve=2)
    expect_null(clarification$state$draft)
    expect_equal(nrow(list_configurations(repo,other$v$version_id)),1L)
  })
})
