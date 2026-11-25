test_that("date suggestions wait for exact approval and persist through revisions/restart", {
  repo<-new_test_repo()
  f<-full_fixture(repo,write_fixture("data_campionamento,value\n03/04/2020,NA\n"))
  original<-get_configuration(repo,f$cfg$config_id)
  q<-prepare_clarifications(repo,f$v$version_id,f$cfg$config_id)
  date<-Filter(function(x)x$type=="date_mapping",q$questions)[[1]]
  expect_equal(date$status,"pending")
  expect_false(date$suggestions[[1]]$confirmed)
  draft<-preview_clarification_answer(repo,q,date$question_id,
    list(date_role="sampling_date",columns=c(value=0)), "Operator confirmed field role","alice")
  expect_equal(nrow(list_configurations(repo,f$v$version_id)),1L)
  expect_error(approve_clarification_answer(repo,draft,FALSE),"approval")
  expect_error(approve_clarification_answer(repo,draft),"approval")
  saved<-approve_clarification_answer(repo,draft,TRUE)
  expect_equal(saved$revision,2L)
  expect_equal(saved$parent_config_id,f$cfg$config_id)
  expect_equal(saved$clarifications[[1]]$actor_id,"alice")
  expect_true(saved$clarifications[[1]]$approved)
  expect_equal(saved$validation_spec$date_mappings[[1]]$source,"user")
  expect_equal(saved$validation_spec$date_mappings[[1]]$date_role,"sampling_date")
  expect_true(saved$validation_spec$date_mappings[[1]]$confirmed)
  expect_identical(get_configuration(repo,f$cfg$config_id),original)
  p<-assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,saved$config_id))
  expect_equal(p$dates[[1]]$status,"ready")
  expect_equal(p$dates[[1]]$scientific_rows_evaluated,0L)
  expect_error(approve_clarification_answer(repo,draft,TRUE),"stale")
  next_config<-save_configuration(repo,f$v$version_id,parsers=saved$parsers,
    metadata=saved$metadata,schema=saved$schema,expected_revision=2,actor_id="bob")
  expect_equal(next_config$clarifications,saved$clarifications)
  other<-open_repository(repo$root);on.exit(close_repository(other),add=TRUE)
  expect_equal(get_configuration(other,next_config$config_id)$clarifications,saved$clarifications)
  expect_equal(nrow(list_operations(repo)),0L)
  expect_true(verify_input(repo,f$v$version_id)$ok)
})

test_that("clarification drafts bind exact source, lifecycle, role and schema", {
  repo<-new_test_repo();f<-full_fixture(repo,write_fixture("date\n2020\n"))
  q<-prepare_clarifications(repo,f$v$version_id,f$cfg$config_id)
  question<-q$questions[[1]]
  expect_error(preview_clarification_answer(repo,q,"foreign",list(),"why","actor"),"question")
  expect_error(preview_clarification_answer(repo,q,question$question_id,list(date_role="",columns=c(value=0)),"why","actor"),"role")
  expect_error(preview_clarification_answer(repo,q,question$question_id,list(date_role="sampling",columns=c(value=99)),"why","actor"),"position")
  d<-preview_clarification_answer(repo,q,question$question_id,list(date_role="sampling",columns=c(value=0)),"Explicit role","actor")
  changed<-d;changed$answer$date_role<-"changed"
  expect_error(approve_clarification_answer(repo,changed,TRUE),"draft")
  set_workspace_state(repo,f$v$version_id,"removed",0L,"remove-clarification","actor")
  expect_error(approve_clarification_answer(repo,d,TRUE),"removed|active|revision")
  expect_equal(nrow(list_configurations(repo,f$v$version_id)),1L)
})

test_that("explicit parser approval gates ambiguous settings and retains evidence", {
  repo<-new_test_repo();path<-write_fixture("date\n2020\n")
  v<-register_uploaded_inputs(repo,data.frame(name="one.csv",size=file.info(path)$size,type="",datapath=path),"Single column","tester")
  q<-prepare_clarifications(repo,v$version_id,v$config_id)
  parser<-Filter(function(x)x$type=="parser",q$questions)[[1]]
  expect_match(parser$reason,"[Aa]mbiguous|[Uu]nresolved|confirmation")
  expect_true(all(vapply(q$prerequisites$dates,function(x)x$status!="ready",logical(1))))
  answer<-get_configuration(repo,v$config_id)$parsers[[v$resource_ids[1]]]
  d<-preview_clarification_answer(repo,q,parser$question_id,answer,"One column is intentional","alice")
  saved<-approve_clarification_answer(repo,d,TRUE)
  expect_equal(saved$parsers[[v$resource_ids[1]]],answer)
  expect_equal(saved$parser_detection,get_configuration(repo,v$config_id)$parser_detection)
  nextq<-prepare_clarifications(repo,v$version_id,saved$config_id)
  expect_length(Filter(function(x)x$type=="parser",nextq$questions),0L)
  expect_true(length(Filter(function(x)x$type=="date_mapping",nextq$questions))>0L)
})

test_that("missing key indices can be supplied without changing declared keys or dates", {
  repo<-new_test_repo();base<-full_archive()
  con<-unz(base,"meta.xml","rb");xml<-rawToChar(readBin(con,"raw",n=1e6));close(con)
  xml<-sub('<id index="0"/>',"",xml,fixed=TRUE)
  f<-full_fixture(repo,full_archive(descriptor=xml))
  q<-prepare_clarifications(repo,f$v$version_id,f$cfg$config_id)
  key<-Filter(function(x)x$type=="linkage_mapping",q$questions)[[1]]
  expect_equal(q$prerequisites$dates[[1]]$status,"ready")
  d<-preview_clarification_answer(repo,q,key$question_id,
    list(core_position=0,extension_position=0),"Data owner confirmed the missing core identifier","alice")
  saved<-approve_clarification_answer(repo,d,TRUE)
  expect_equal(saved$validation_spec$linkage_mappings[[1]]$source,"user")
  p<-assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,saved$config_id))
  expect_equal(p$linkage[[1]]$status,"ready")
  expect_equal(p$dates[[1]]$status,"ready")
})

test_that("source repair notes remain blocked and preserve independent fields", {
  repo<-new_test_repo();f<-full_fixture(repo,full_archive(include_extension=FALSE))
  q<-prepare_clarifications(repo,f$v$version_id,f$cfg$config_id)
  repair<-Filter(function(x)x$type=="source_repair",q$questions)[[1]]
  d<-preview_clarification_answer(repo,q,repair$question_id,
    list(note="Will obtain the missing extension from the owner"),"Owner contacted","alice")
  saved<-approve_clarification_answer(repo,d,TRUE)
  p<-assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,saved$config_id))
  expect_equal(p$linkage[[1]]$status,"not_evaluated")
  expect_equal(p$dates[[1]]$status,"ready")
  nextq<-prepare_clarifications(repo,f$v$version_id,saved$config_id)
  note<-Filter(function(x)x$type=="source_repair",nextq$questions)[[1]]
  expect_equal(note$status,"awaiting_source")
  expect_equal(note$last_answer$answer$note,"Will obtain the missing extension from the owner")
})

test_that("approval rejects stale concurrent context and source tampering", {
  repo<-new_test_repo();f<-full_fixture(repo,write_fixture("date,value\n2020,NA\n"))
  q<-prepare_clarifications(repo,f$v$version_id,f$cfg$config_id)
  d<-preview_clarification_answer(repo,q,q$questions[[1]]$question_id,
    list(date_role="sampling",columns=c(value=0)),"Owner","alice")
  second<-open_repository(repo$root);on.exit(close_repository(second),add=TRUE)
  make_config(second,f$v$version_id,expected_revision=1L)
  expect_error(approve_clarification_answer(repo,d,TRUE),"stale")
  expect_equal(nrow(list_configurations(repo,f$v$version_id)),2L)
  latest<-utils::tail(list_configurations(repo,f$v$version_id)$config_id,1)
  q<-prepare_clarifications(repo,f$v$version_id,latest)
  d<-preview_clarification_answer(repo,q,q$questions[[1]]$question_id,
    list(date_role="sampling",columns=c(value=0)),"Owner","alice")
  writeBin(charToRaw("modified"),get_input(repo,f$v$version_id)$resources$owned_path)
  expect_error(approve_clarification_answer(repo,d,TRUE),"question|source|integrity")
  expect_equal(nrow(list_configurations(repo,f$v$version_id)),2L)
})

test_that("parser edits cannot reuse an old approval for different settings", {
  repo<-new_test_repo();path<-write_fixture("date\n2020\n")
  v<-register_uploaded_inputs(repo,data.frame(name="one.csv",size=file.info(path)$size,type="",datapath=path),"Single","tester")
  q<-prepare_clarifications(repo,v$version_id,v$config_id)
  parser<-Filter(function(x)x$type=="parser",q$questions)[[1]]
  cfg<-get_configuration(repo,v$config_id)
  d<-preview_clarification_answer(repo,q,parser$question_id,cfg$parsers[[v$resource_ids[1]]],"Intentional single field","alice")
  approved<-approve_clarification_answer(repo,d,TRUE)
  changed<-approved$parsers;changed[[v$resource_ids[1]]]$delimiter<-";"
  nextcfg<-save_configuration(repo,v$version_id,parsers=changed,metadata=approved$metadata,
    schema=approved$schema,parser_detection=approved$parser_detection,expected_revision=2L,actor_id="bob")
  nextq<-prepare_clarifications(repo,v$version_id,nextcfg$config_id)
  expect_length(Filter(function(x)x$type=="parser",nextq$questions),1L)
  expect_equal(nextcfg$clarifications,approved$clarifications)
})

test_that("date approvals preserve independent mappings and catalogue choices", {
  repo<-new_test_repo()
  v<-register_input(write_fixture("date_a,date_b\n2020,2021\n"),list(),repo)
  table<-new_validation_table(v$version_id,v$resource_ids[1],c("date_a","date_b"))
  a<-new_date_mapping(table,"a","sampling_date",c(value=0),"user","owner","Known",TRUE)
  b<-new_date_mapping(table,"b","analysis_date",c(value=1),"suggested","suggester","Candidate")
  spec<-new_validation_spec(list(a,b),enabled_rules=c("PRE-01","TMP-00"),enabled_patterns="ymd-dash")
  cfg<-make_config(repo,v$version_id,validation_spec=spec,metadata=list(site="Venezia"))
  q<-prepare_clarifications(repo,v$version_id,cfg$config_id)
  item<-Filter(function(x)x$type=="date_mapping",q$questions)[[1]]
  expect_false(item$suggestions[[1]]$confirmed)
  draft<-preview_clarification_answer(repo,q,item$question_id,
    list(date_role="analysis_date",columns=c(value=1),date_order="DMY",date_order_evidence="Owner codebook"),"Owner codebook","alice")
  saved<-approve_clarification_answer(repo,draft,TRUE)
  expect_equal(saved$metadata,cfg$metadata)
  expect_equal(saved$parsers,cfg$parsers)
  expect_equal(saved$validation_spec$enabled_rules,cfg$validation_spec$enabled_rules)
  expect_equal(saved$validation_spec$patterns,cfg$validation_spec$patterns)
  expect_equal(saved$validation_spec$date_mappings[[1]],a)
  expect_equal(saved$validation_spec$date_mappings[[2]]$date_order,"DMY")
})

test_that("unapproved or foreign clarification receipts cannot be saved", {
  repo<-new_test_repo();f<-full_fixture(repo,write_fixture("date\n2020\n"))
  q<-prepare_clarifications(repo,f$v$version_id,f$cfg$config_id)
  d<-preview_clarification_answer(repo,q,q$questions[[1]]$question_id,
    list(date_role="sampling",columns=c(value=0)),"Owner","alice")
  saved<-approve_clarification_answer(repo,d,TRUE)
  bad<-saved$clarifications;bad[[1]]$approved<-FALSE
  expect_error(save_configuration(repo,f$v$version_id,expected_revision=2,actor_id="alice",clarifications=bad),"approved")
  bad<-saved$clarifications;bad[[1]]$resource_id<-"foreign"
  expect_error(save_configuration(repo,f$v$version_id,expected_revision=2,actor_id="alice",clarifications=bad),"receipt")
  expect_equal(nrow(list_configurations(repo,f$v$version_id)),2L)
})

test_that("approving one suggestion leaves independent unsaved date fields pending", {
  repo<-new_test_repo();f<-full_fixture(repo,write_fixture("anno,giorno,mese,data_analisi\n2020,7,03,03/04/2020\n"))
  q<-prepare_clarifications(repo,f$v$version_id,f$cfg$config_id)
  split<-Filter(function(q)q$type=="date_mapping"&&length(q$mapping$columns)==3L,q$questions)[[1]]
  d<-preview_clarification_answer(repo,q,split$question_id,
    list(date_role="sampling_date",columns=c(year=0,day=1,month=2)),"Known synthetic roles","alice")
  saved<-approve_clarification_answer(repo,d,TRUE)
  nextq<-prepare_clarifications(repo,f$v$version_id,saved$config_id)
  remaining<-Filter(function(q)q$type=="date_mapping",nextq$questions)
  expect_length(remaining,1L)
  expect_equal(remaining[[1]]$mapping$columns$value$position,3)
  expect_equal(vapply(nextq$prerequisites$dates,function(x)x$status,character(1)),c("ready","not_evaluated"))
})

test_that("ambiguous invalid or out-of-range descriptor keys require source repair", {
  repo<-new_test_repo();base<-full_archive()
  con<-unz(base,"meta.xml","rb");xml<-rawToChar(readBin(con,"raw",n=1e6));close(con)
  for(key in c('<id index="0"/><id index="1"/>','<id index="99"/>','<id index="bad"/>')) {
    f<-full_fixture(repo,full_archive(descriptor=sub('<id index="0"/>',key,xml,fixed=TRUE)))
    q<-prepare_clarifications(repo,f$v$version_id,f$cfg$config_id)
    expect_length(Filter(function(q)q$type=="linkage_mapping",q$questions),0L)
    expect_true(length(Filter(function(q)q$type=="source_repair",q$questions))>0L)
    x<-q$preparation
    forged<-new_linkage_mapping(x$tables[[1]]$schema,2,x$tables[[2]]$schema,0,
      "manual-invalid","owner","Contradictory metadata",TRUE,source="user")
    cfg<-make_config(repo,f$v$version_id,expected_revision=1L,validation_spec=new_validation_spec(linkage_mappings=list(forged)))
    p<-assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,cfg$config_id))
    expect_equal(p$linkage[[1]]$status,"not_evaluated")
    expect_equal(p$dates[[1]]$status,"ready")
  }
})

test_that("competing same-relationship mappings are explicitly replaced after review", {
  repo<-new_test_repo();v<-register_input(full_archive(),list(),repo)
  core<-new_validation_table(v$version_id,v$resource_ids[1],c("id","occurrenceID","Date observed"),"core.csv")
  ext<-new_validation_table(v$version_id,v$resource_ids[1],c("coreid","value"),"measurements.csv")
  a<-new_linkage_mapping(core,0,ext,0,"a","owner","Declared",TRUE)
  b<-new_linkage_mapping(core,0,ext,0,"b","owner","Duplicate declaration",TRUE)
  cfg<-make_config(repo,v$version_id,validation_spec=new_validation_spec(linkage_mappings=list(a,b)))
  q<-prepare_clarifications(repo,v$version_id,cfg$config_id)
  item<-Filter(function(q)q$type=="linkage_mapping",q$questions)[[1]]
  d<-preview_clarification_answer(repo,q,item$question_id,list(core_position=0,extension_position=0),"Select exact relationship","alice")
  expect_setequal(vapply(d$replacements,function(x)x$mapping_id,character(1)),c("a","b"))
  saved<-approve_clarification_answer(repo,d,TRUE)
  expect_length(saved$validation_spec$linkage_mappings,1L)
  p<-assess_validation_prerequisites(read_validation_tables(repo,v$version_id,saved$config_id))
  expect_equal(p$linkage[[1]]$status,"ready")
  expect_length(cfg$validation_spec$linkage_mappings,2L)
})

test_that("correcting a stale schema explicitly retires conflicting old mappings", {
  repo<-new_test_repo();v<-register_input(write_fixture("first_date,second_date\n2020,2021\n"),list(),repo)
  old<-new_validation_table(v$version_id,v$resource_ids[1],c("old1","old2"))
  a<-new_date_mapping(old,"a","sampling",c(value=0),"user","owner","Old",TRUE)
  b<-new_date_mapping(old,"b","analysis",c(value=1),"user","owner","Old",TRUE)
  cfg<-make_config(repo,v$version_id,validation_spec=new_validation_spec(list(a,b)))
  q<-prepare_clarifications(repo,v$version_id,cfg$config_id)
  item<-Filter(function(q)q$type=="date_mapping",q$questions)[[1]]
  d<-preview_clarification_answer(repo,q,item$question_id,list(date_role="sampling",columns=c(value=0)),"Recheck current headers","alice")
  expect_setequal(vapply(d$replacements,function(x)x$mapping_id,character(1)),c("a","b"))
  expect_match(clarification_review_text(d),"old|schema|Schema")
  saved<-approve_clarification_answer(repo,d,TRUE)
  expect_length(saved$validation_spec$date_mappings,1L)
  expect_length(saved$clarifications[[1]]$superseded_mappings,2L)
  after<-prepare_clarifications(repo,v$version_id,saved$config_id)
  expect_equal(sum(vapply(after$prerequisites$dates,function(d)d$status=="ready",logical(1))),1L)
  expect_true(length(Filter(function(q)q$type=="date_mapping",after$questions))>0L)
})

test_that("unresolved parser evidence cannot disappear through ordinary config saves", {
  repo<-new_test_repo();path<-write_fixture("date\n2020\n")
  v<-register_uploaded_inputs(repo,data.frame(name="single.csv",size=file.info(path)$size,type="",datapath=path),"One column","owner")
  cfg<-get_configuration(repo,v$config_id)
  for(revision in 1:2) {
    cfg<-save_configuration(repo,v$version_id,parsers=cfg$parsers,schema=cfg$schema,
      metadata=list(note="unrelated edit"),expected_revision=revision,actor_id="bob",
      parser_detection=if(revision==1)NULL else list())
    q<-prepare_clarifications(repo,v$version_id,cfg$config_id)
    expect_length(Filter(function(q)q$type=="parser",q$questions),1L)
    expect_equal(q$prerequisites$table_checks[[1]]$status,"not_evaluated")
  }
})

test_that("damaged source bytes cannot receive a parser or mapping approval", {
  repo<-new_test_repo();f<-full_fixture(repo,write_fixture("date,value\n2020,NA\n"))
  writeBin(charToRaw("tampered"),get_input(repo,f$v$version_id)$resources$owned_path)
  q<-prepare_clarifications(repo,f$v$version_id,f$cfg$config_id)
  expect_length(Filter(function(q)q$type=="parser",q$questions),0L)
  expect_length(Filter(function(q)q$type=="date_mapping",q$questions),0L)
  expect_true(all(vapply(q$questions,function(q)q$type=="source_repair",logical(1))))
  expect_match(q$questions[[1]]$reason,"integrity")
  expect_equal(nrow(list_configurations(repo,f$v$version_id)),1L)
})
