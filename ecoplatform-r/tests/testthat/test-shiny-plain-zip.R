test_that("Shiny plain-member settings use review approval and preserve sibling pending state", {
  repo<-new_test_repo();f<-full_fixture(repo,plain_zip_fixture())
  shiny::testServer(workspace_server,args=list(repo=repo),{
    session$setInputs(actor="owner",version=f$v$version_id,resource=f$v$resource_ids[1],config=f$cfg$config_id)
    session$setInputs(form_context=current_context()$token,clarify_load=1)
    q<-Filter(function(q)q$type=="archive_parser",clarification$state$request$questions)[[1]]
    session$setInputs(clarify_question=q$question_id)
    expect_match(as.character(output$clarification_form$html),"Occurrence.tsv")
    session$setInputs(clarify_encoding="UTF-8",clarify_delimiter="\t",clarify_decimal=".",
      clarify_quote='"',clarify_header=TRUE,clarify_evidence="Synthetic owner declares header",clarify_review=1)
    expect_false(is.null(clarification$state$draft))
    expect_equal(nrow(list_configurations(repo,f$v$version_id)),1L)
    session$setInputs(clarify_cancel=1)
    expect_equal(nrow(list_configurations(repo,f$v$version_id)),1L)
    session$setInputs(clarify_review=2,clarify_approve=1)
    saved<-get_configuration(repo,utils::tail(list_configurations(repo,f$v$version_id)$config_id,1))
    expect_equal(saved$revision,2L)
    expect_true(saved$archive_settings[[f$v$resource_ids[1]]][[q$member]]$header)
    session$setInputs(config=saved$config_id)
    expect_match(as.character(output$clarification_history),"Occurrence.tsv")
  })
})

test_that("Shiny plain ZIP relationship review names both actual members and keys", {
  repo<-new_test_repo();f<-full_fixture(repo,plain_zip_fixture())
  cfg<-approve_zip_settings(repo,f$v$version_id,f$cfg$config_id,"Occurrence.tsv")
  cfg<-approve_zip_settings(repo,f$v$version_id,cfg$config_id,"MeasurementOrFact.tsv")
  shiny::testServer(workspace_server,args=list(repo=repo),{
    session$setInputs(actor="owner",version=f$v$version_id,resource=f$v$resource_ids[1],config=cfg$config_id)
    session$setInputs(form_context=current_context()$token,clarify_load=1)
    q<-Filter(function(q)q$type=="archive_linkage",clarification$state$request$questions)[[1]]
    pair<-q$suggestions[[1]]$answer
    session$setInputs(clarify_question=q$question_id,
      clarify_core_table=pair$core_table_id,clarify_extension_table=pair$extension_table_id)
    expect_match(as.character(output$archive_linkage_columns$html),"key")
    session$setInputs(clarify_core="0",clarify_reference="0",clarify_evidence="Explicit synthetic relationship",clarify_review=1)
    expect_match(clarification_review_text(clarification$state$draft),"Occurrence.tsv")
    expect_match(clarification_review_text(clarification$state$draft),"MeasurementOrFact.tsv")
    expect_equal(nrow(list_configurations(repo,f$v$version_id)),3L)
    session$setInputs(clarify_approve=1)
    saved<-get_configuration(repo,utils::tail(list_configurations(repo,f$v$version_id)$config_id,1))
    expect_equal(saved$revision,4L)
    expect_equal(saved$validation_spec$linkage_mappings[[1]]$source,"user")
  })
})
