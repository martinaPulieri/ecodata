test_that("saved missing relationships remain visible alongside usable descriptor siblings", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  input<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  missing<-new_validation_table(f$v$version_id,f$v$resource_ids[1],c("ref"),"archived.csv")
  mapping<-new_linkage_mapping(input$tables[[1]]$schema,0,missing,0,"saved_missing","owner","Saved absent member",TRUE)
  cfg<-make_config(repo,f$v$version_id,expected_revision=1L,
    validation_spec=new_validation_spec(linkage_mappings=list(mapping)))
  r<-run_linkage_validation(repo,f$v$version_id,cfg$config_id)
  expect_equal(r$status,"completed_with_limitations")
  expect_setequal(vapply(r$mappings,function(m)m$mapping_id,character(1)),
    c(paste0("descriptor-link:",input$tables[[2]]$table_id),"saved_missing"))
  expect_equal(vapply(r$mappings,function(m)m$status,character(1)),c("completed","not_evaluated"))
  selected<-run_linkage_validation(repo,f$v$version_id,cfg$config_id,mapping_id="saved_missing")
  expect_equal(selected$mappings[[1]]$status,"not_evaluated")
  expect_null(selected$mappings[[1]]$extension_population)
})

test_that("post-run integrity invalidates populations and readiness only on damaged resources", {
  repo<-new_test_repo()
  v<-register_input(c(full_archive(),full_archive()),list(),repo);cfg<-make_config(repo,v$version_id)
  verify<-verify_input;calls<-0L
  testthat::with_mocked_bindings({
    r<-run_linkage_validation(repo,v$version_id,cfg$config_id)
    expect_equal(r$mappings[[1]]$status,"unreadable")
    expect_null(r$mappings[[1]]$core_population)
    expect_null(r$mappings[[1]]$extension_population)
    expect_equal(r$prerequisites[[1]]$status,"not_evaluated")
    expect_null(r$prerequisites[[1]]$population_count)
    dates<-Filter(function(p)identical(p$resource_id,v$resource_ids[1]),r$date_prerequisites)
    expect_true(all(vapply(dates,function(p)p$status=="not_evaluated"&&is.null(p$population_count)&&p$eligible_rows==0L,logical(1))))
    expect_equal(r$mappings[[2]]$status,"completed")
    expect_equal(r$prerequisites[[2]]$status,"ready")
    expect_equal(r$mappings[[2]]$extension_population,2L)
  },verify_input=function(repo,version_id){
    calls<<-calls+1L
    if(calls==3L)writeBin(charToRaw("changed"),get_input(repo,version_id)$resources$owned_path[1])
    verify(repo,version_id)
  },.package="ecodata")
})

review_scope_input<-function(repo,core,ext) {
  f<-full_fixture(repo,plain_zip_fixture(list(
    "Occurrence.tsv"=paste0("dataset_id\tid\n",core),
    "MeasurementOrFact.tsv"=paste0("dataset_id\tid\n",ext))))
  read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
}
review_scope_audit<-function(input)compare_linkage_key_scope(input,
  input$tables[[1]]$table_id,input$tables[[2]]$table_id,1,1,0,0)

test_that("scope diagnostics never invent tuples for empty source populations", {
  repo<-new_test_repo()
  for(core in c("","A\t001\n")) {
    r<-review_scope_audit(review_scope_input(repo,core,""))
    expect_equal(sum(unlist(r$compound_key$matching)),0L)
    expect_equal(r$compound_key$core_unique_nonmissing_keys,if(nzchar(core))1L else 0L)
    expect_equal(r$resolution,"insufficient_information")
  }
})

test_that("a known bare ID in absent namespace is a conflict even with multiple targets", {
  repo<-new_test_repo()
  r<-review_scope_audit(review_scope_input(repo,"A\t123\nB\t123\n","C\t123\n"))
  expect_equal(r$single_key$matching$ambiguous,1L)
  expect_equal(r$compound_key$matching$unresolved_reference,1L)
  expect_equal(r$namespace_disagreements,1L)
  expect_equal(r$resolution,"namespace_conflict")
})

test_that("blocked row materialisation obeys cancellation and drops partial records", {
  repo<-new_test_repo()
  f<-linkage_engine_fixture(repo,extension=paste0("coreid,value\n",paste(rep("001,1",150),collapse="\n"),"\n"))
  input<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  mapping<-new_linkage_mapping(input$tables[[1]]$schema,0,input$tables[[2]]$schema,0,"unconfirmed","owner","Pending")
  cfg<-make_config(repo,f$v$version_id,expected_revision=1L,validation_spec=new_validation_spec(linkage_mappings=list(mapping)))
  flag<-FALSE;constructed<-0L;build<-new_linkage_result
  testthat::with_mocked_bindings({
    r<-run_linkage_validation(repo,f$v$version_id,cfg$config_id,cancelled=function()flag)
    expect_equal(r$status,"cancelled")
    expect_length(r$mappings[[1]]$rows,0L)
    expect_null(r$mappings[[1]]$summary)
    expect_equal(r$mappings[[1]]$evaluated_measurements,0L)
    expect_lte(constructed,128L)
  },new_linkage_result=function(...) {
    row<-build(...);constructed<<-constructed+1L;flag<<-TRUE;row
  },.package="ecodata")
})

test_that("linkage summary reconstruction can be interrupted cooperatively", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  r<-run_linkage_validation(repo,f$v$version_id,f$cfg$config_id)
  m<-r$mappings[[1]]
  expect_error(summarise_linkage_results(m$context,m$mapping_id,m$rows,2L,
    cancelled=function()TRUE),class="ecodata_read_cancelled")
})

test_that("effective descriptor IDs cannot silently collide with a different saved declaration", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  input<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  missing<-new_validation_table(f$v$version_id,f$v$resource_ids[1],c("ref"),"missing.csv")
  id<-paste0("descriptor-link:",input$tables[[2]]$table_id)
  map<-new_linkage_mapping(input$tables[[1]]$schema,0,missing,0,id,"owner","Conflicting identifier",TRUE)
  cfg<-make_config(repo,f$v$version_id,expected_revision=1L,validation_spec=new_validation_spec(linkage_mappings=list(map)))
  r<-run_linkage_validation(repo,f$v$version_id,cfg$config_id)
  expect_equal(r$status,"completed_with_limitations")
  expect_true(all(vapply(r$mappings,function(m)m$evaluated_measurements==0L,logical(1))))
  expect_error(run_linkage_validation(repo,f$v$version_id,cfg$config_id,mapping_id=id),"ambiguous")
})

test_that("whitespace evidence exposes Unicode codepoints while equality stays exact", {
  repo<-new_test_repo()
  f<-linkage_engine_fixture(repo,core="id,occurrenceID,Date observed\n\u00a0x,a,2020\n",
    extension="coreid,value\n\u00a0x,1\nx,2\n")
  m<-run_linkage_validation(repo,f$v$version_id,f$cfg$config_id)$mappings[[1]]
  expect_equal(m$summary$counts$linked,1L)
  expect_equal(m$summary$counts$unresolved_reference,1L)
  warnings<-Filter(function(f)f$rule_id=="LNK-08",m$findings)
  expect_length(warnings,2L)
  expect_true(all(vapply(warnings,function(f)grepl("U+00A0",f$reason,fixed=TRUE),logical(1))))
})
