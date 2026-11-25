test_that("exact linkage produces one measurement outcome and independent diagnostic counts", {
  repo<-new_test_repo();f<-linkage_engine_fixture(repo)
  before<-get_configuration(repo,f$cfg$config_id)
  result<-run_linkage_validation(repo,f$v$version_id,f$cfg$config_id)
  expect_equal(result$contract_version,"linkage-evaluation-1.0")
  expect_equal(result$status,"completed")
  expect_length(result$mappings,1L)
  m<-result$mappings[[1]]
  expect_equal(m$status,"completed")
  expect_equal(m$core_population,7L)
  expect_equal(m$extension_population,9L)
  expect_equal(vapply(m$rows,function(x)x$outcome,character(1)),
    c("linked","linked","ambiguous","missing_reference","unresolved_reference","linked","unresolved_reference","linked","unresolved_reference"))
  expect_equal(unlist(m$summary$counts)[c("linked","ambiguous","missing_reference","unresolved_reference","not_evaluated")],c(linked=4,ambiguous=1,missing_reference=1,unresolved_reference=3,not_evaluated=0))
  expect_equal(m$summary$population_count,9L)
  expect_length(m$rows[[3]]$candidate_core_locators,2L)
  expect_equal(m$rows[[7]]$original_reference,"001 ")
  expect_equal(m$rows[[6]]$original_reference,"NA")
  rules<-vapply(m$findings,function(x)x$rule_id,character(1))
  expect_equal(sum(rules=="LNK-02"),1L)
  expect_equal(sum(rules=="LNK-03"),1L)
  expect_equal(sum(rules=="LNK-04"),1L)
  expect_equal(sum(rules=="LNK-05"),3L)
  expect_equal(sum(rules=="LNK-06"),1L)
  expect_equal(sum(rules=="LNK-08"),3L) # core leading space; leading/trailing extension spaces
  dup<-m$findings[[which(rules=="LNK-03")]]
  expect_equal(unlist(dup$row_numbers),c(2,3))
  expect_equal(m$multiplicity$core_missing_rows,1L)
  expect_equal(m$multiplicity$core_duplicate_groups,1L)
  expect_equal(m$multiplicity$core_duplicate_rows,2L)
  expect_equal(m$multiplicity$unique_core_rows_without_measurements,1L)
  expect_equal(m$multiplicity$uniquely_linked_core_rows,3L)
  expect_equal(m$evaluated_measurements,9L)
  expect_true(all(vapply(m$checks,function(x)x$execution_state=="completed"&&x$coverage=="complete",logical(1))))
  expect_equal(get_configuration(repo,f$cfg$config_id),before)
  expect_equal(nrow(list_configurations(repo,f$v$version_id)),1L)
  expect_equal(nrow(list_operations(repo)),0L)
  expect_true(verify_input(repo,f$v$version_id)$ok)
  expect_null(before$validation_spec)
  expect_equal(result$rules_source,"application_defaults")
  expect_equal(result$context$config_hash,before$context_hash)
  expect_equal(result$context$validation_spec$linkage_mappings[[1]]$source,"descriptor")
  expect_equal(summarise_linkage_results(result$context,m$mapping_id,m$rows,9L),m$summary)
})

test_that("empty populations and literal text retain exact semantics", {
  repo<-new_test_repo()
  f<-linkage_engine_fixture(repo,core="id,occurrenceID,Date observed\n",extension="coreid,value\n")
  r<-run_linkage_validation(repo,f$v$version_id,f$cfg$config_id)
  m<-r$mappings[[1]]
  expect_equal(m$status,"completed");expect_length(m$rows,0L)
  expect_equal(sum(unlist(m$summary$counts)),0L)
  expect_equal(m$multiplicity$unique_core_rows_without_measurements,0L)
  f<-linkage_engine_fixture(repo,core="id,occurrenceID,Date observed\nA,a,2020\n001,b,2020\nNA,c,2020\n",
    extension="coreid,value\na,1\n1,2\nNA,3\n\u00a0,4\n")
  m<-run_linkage_validation(repo,f$v$version_id,f$cfg$config_id)$mappings[[1]]
  expect_equal(vapply(m$rows,function(x)x$outcome,character(1)),
    c("unresolved_reference","unresolved_reference","linked","missing_reference"))
})

test_that("candidate findings and output quotas never present partial execution as complete", {
  repo<-new_test_repo();f<-linkage_engine_fixture(repo)
  for(args in list(list(max_candidate_targets=1L),list(max_findings=1L),list(max_output_rows=1L))) {
    r<-do.call(run_linkage_validation,c(list(repo=repo,version_id=f$v$version_id,config_id=f$cfg$config_id),args))
    expect_equal(r$status,"completed_with_limitations")
    expect_equal(r$mappings[[1]]$status,"limited")
    expect_equal(r$mappings[[1]]$evaluated_measurements,0L)
    expect_true(all(vapply(r$mappings[[1]]$rows,function(x)x$outcome=="not_evaluated",logical(1))))
    expect_match(r$mappings[[1]]$reason,"quota")
  }
  r<-run_linkage_validation(repo,f$v$version_id,f$cfg$config_id,cancelled=function()TRUE)
  expect_equal(r$status,"cancelled")
  expect_equal(sum(vapply(r$mappings,function(m)m$evaluated_measurements,numeric(1))),0L)
})

test_that("saved unconfirmed mappings remain not evaluated and disabled optional rules are disclosed", {
  repo<-new_test_repo();f<-linkage_engine_fixture(repo)
  p<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  mapping<-new_linkage_mapping(p$tables[[1]]$schema,0,p$tables[[2]]$schema,0,"link","owner","Unconfirmed")
  cfg<-make_config(repo,f$v$version_id,expected_revision=1L,validation_spec=new_validation_spec(linkage_mappings=list(mapping)))
  r<-run_linkage_validation(repo,f$v$version_id,cfg$config_id)
  expect_equal(r$mappings[[1]]$status,"not_evaluated")
  expect_equal(r$mappings[[1]]$summary$counts$not_evaluated,9L)
  expect_equal(r$mappings[[1]]$evaluated_measurements,0L)
  mapping$confirmed<-TRUE
  spec<-new_validation_spec(linkage_mappings=list(mapping),enabled_rules=paste0("LNK-0",1:6))
  cfg<-make_config(repo,f$v$version_id,expected_revision=2L,validation_spec=spec)
  r<-run_linkage_validation(repo,f$v$version_id,cfg$config_id)
  expect_equal(r$mappings[[1]]$status,"completed")
  expect_null(r$mappings[[1]]$multiplicity)
  expect_setequal(unlist(r$mappings[[1]]$disabled_rules),c("LNK-07","LNK-08"))
  expect_false(any(vapply(r$mappings[[1]]$findings,function(f)f$rule_id=="LNK-08",logical(1))))
  spec<-new_validation_spec(linkage_mappings=list(mapping),enabled_rules=c("LNK-01","LNK-02"))
  cfg<-make_config(repo,f$v$version_id,expected_revision=3L,validation_spec=spec)
  r<-run_linkage_validation(repo,f$v$version_id,cfg$config_id)
  expect_equal(r$mappings[[1]]$status,"not_evaluated")
  expect_match(r$mappings[[1]]$reason,"mandatory")
})

test_that("missing extension does not disable date preparation or invent measurement populations", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive(include_extension=FALSE))
  r<-run_linkage_validation(repo,f$v$version_id,f$cfg$config_id)
  expect_equal(r$mappings[[1]]$status,"not_evaluated")
  expect_null(r$mappings[[1]]$extension_population)
  expect_null(r$mappings[[1]]$summary)
  expect_equal(r$date_prerequisites[[1]]$status,"ready")
  expect_error(run_linkage_validation(repo,"wrong",f$cfg$config_id),"different version")
  set_workspace_state(repo,f$v$version_id,"removed",0L,"remove-linkage","owner")
  expect_error(run_linkage_validation(repo,f$v$version_id,f$cfg$config_id),"removed|active")
})

test_that("standalone data has no invented measurement population", {
  repo<-new_test_repo();f<-full_fixture(repo,write_fixture("id,date\n001,2020\n"))
  r<-run_linkage_validation(repo,f$v$version_id,f$cfg$config_id)
  expect_equal(r$status,"not_applicable")
  expect_null(r$mappings[[1]]$extension_population)
  expect_null(r$mappings[[1]]$summary)
})

test_that("whole-run budgets bound multiple valid relationships without multiplying output", {
  repo<-new_test_repo()
  v<-register_input(c(full_archive(),full_archive()),list(),repo)
  cfg<-make_config(repo,v$version_id)
  r<-run_linkage_validation(repo,v$version_id,cfg$config_id,max_output_rows=4L)
  expect_equal(vapply(r$mappings,function(m)m$status,character(1)),c("completed","limited"))
  expect_lte(sum(vapply(r$mappings,function(m)length(m$rows),numeric(1))),4L)
  expect_equal(r$mappings[[2]]$evaluated_measurements,0L)
})

test_that("bad siblings do not block an independent relationship and contexts stay scoped", {
  repo<-new_test_repo()
  v<-register_input(c(full_archive(include_extension=FALSE),full_archive()),list(),repo)
  cfg<-make_config(repo,v$version_id)
  r<-run_linkage_validation(repo,v$version_id,cfg$config_id)
  expect_equal(vapply(r$mappings,function(m)m$status,character(1)),c("not_evaluated","completed"))
  expect_equal(r$mappings[[2]]$summary$counts$linked,2L)
  expect_equal(r$mappings[[2]]$context$resources[[1]]$resource_id,v$resource_ids[2])
  expect_true(any(vapply(r$date_prerequisites,function(p)p$status=="ready",logical(1))))
  expect_error(run_linkage_validation(repo,v$version_id,cfg$config_id,mapping_id="foreign"),"mapping_id")
})

test_that("generic approved ZIP relationship uses the same exact engine without new writes", {
  repo<-new_test_repo();f<-full_fixture(repo,plain_zip_fixture())
  cfg<-approve_zip_settings(repo,f$v$version_id,f$cfg$config_id,"Occurrence.tsv")
  cfg<-approve_zip_settings(repo,f$v$version_id,cfg$config_id,"MeasurementOrFact.tsv")
  q<-prepare_clarifications(repo,f$v$version_id,cfg$config_id)
  item<-Filter(function(q)q$type=="archive_linkage",q$questions)[[1]]
  d<-preview_clarification_answer(repo,q,item$question_id,item$suggestions[[1]]$answer,"Explicit synthetic relationship","owner")
  cfg<-approve_clarification_answer(repo,d,TRUE)
  before<-list_configurations(repo,f$v$version_id)
  r<-run_linkage_validation(repo,f$v$version_id,cfg$config_id)
  expect_equal(r$status,"completed")
  expect_equal(r$rules_source,"configuration")
  expect_equal(r$mappings[[1]]$summary$counts$linked,2L)
  expect_equal(r$mappings[[1]]$context$validation_spec$linkage_mappings[[1]]$source,"user")
  expect_equal(list_configurations(repo,f$v$version_id),before)
})

test_that("post-evaluation source changes discard scientific records instead of reusing success", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive())
  verify<-verify_input;calls<-0L
  testthat::with_mocked_bindings({
    r<-run_linkage_validation(repo,f$v$version_id,f$cfg$config_id)
    expect_equal(r$mappings[[1]]$status,"unreadable")
    expect_equal(r$mappings[[1]]$evaluated_measurements,0L)
    expect_length(r$mappings[[1]]$rows,0L)
    expect_length(r$mappings[[1]]$findings,0L)
    expect_null(r$mappings[[1]]$summary)
  },verify_input=function(repo,version_id) {
    calls<<-calls+1L
    if(calls==3L)writeBin(charToRaw("tampered"),get_input(repo,version_id)$resources$owned_path)
    verify(repo,version_id)
  },.package="ecodata")
})

test_that("cancellation during row construction discards partial outcomes", {
  repo<-new_test_repo();f<-linkage_engine_fixture(repo)
  inside<-0L
  cancel<-function(){
    active<-any(vapply(sys.calls(),function(call)grepl("evaluate_linkage_mapping",deparse(call)[1],fixed=TRUE),logical(1)))
    if(active)inside<<-inside+1L
    inside>=3L
  }
  r<-run_linkage_validation(repo,f$v$version_id,f$cfg$config_id,cancelled=cancel)
  expect_equal(r$status,"cancelled")
  expect_equal(r$mappings[[1]]$evaluated_measurements,0L)
  expect_length(r$mappings[[1]]$rows,0L)
})
