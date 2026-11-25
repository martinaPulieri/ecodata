test_that("plain ZIP reads independent tables without inventing a descriptor or approvals", {
  repo<-new_test_repo();f<-full_fixture(repo,plain_zip_fixture())
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  expect_length(x$tables,2L)
  expect_equal(vapply(x$tables,function(t)t$status,character(1)),c("complete","complete"))
  expect_equal(x$tables[[1]]$data[[1]],c("001","002"))
  expect_equal(x$tables[[1]]$loaded_rows,2L)
  expect_null(x$tables[[1]]$population_count)
  expect_null(x$tables[[1]]$declaration)
  expect_true(x$tables[[1]]$settings_pending)
  expect_equal(x$tables[[1]]$archive_mode,"plain_zip")
  expect_equal(x$resources[[1]]$ignored_members,list("query.json","citations.html"))
  p<-assess_validation_prerequisites(x)
  expect_true(all(vapply(p$table_checks,function(c)c$status=="not_evaluated",logical(1))))
  expect_equal(p$linkage[[1]]$status,"not_evaluated")
  expect_true(all(vapply(p$dates,function(c)c$status=="not_evaluated",logical(1))))
  expect_equal(nrow(list_configurations(repo,f$v$version_id)),1L)
  expect_true(verify_input(repo,f$v$version_id)$ok)
})

test_that("member settings require approval and apply only to the exact member", {
  repo<-new_test_repo();f<-full_fixture(repo,plain_zip_fixture())
  original<-get_configuration(repo,f$cfg$config_id)
  q<-prepare_clarifications(repo,f$v$version_id,f$cfg$config_id)
  items<-Filter(function(q)q$type=="archive_parser",q$questions)
  expect_length(items,2L);expect_true(all(vapply(items,function(q)!q$suggestions[[1]]$confirmed,logical(1))))
  item<-items[[1]];draft<-preview_clarification_answer(repo,q,item$question_id,
    item$suggestions[[1]]$answer,"Synthetic exact format","owner")
  expect_equal(nrow(list_configurations(repo,f$v$version_id)),1L)
  expect_error(approve_clarification_answer(repo,draft,FALSE),"approval")
  saved<-approve_clarification_answer(repo,draft,TRUE)
  expect_equal(saved$revision,2L)
  expect_true(saved$archive_settings[[f$v$resource_ids[1]]][[item$member]]$header)
  x<-read_validation_tables(repo,f$v$version_id,saved$config_id)
  expect_false(x$tables[[1]]$settings_pending)
  expect_true(x$tables[[2]]$settings_pending)
  expect_equal(x$tables[[1]]$population_count,2L)
  expect_null(x$tables[[2]]$population_count)
  nextcfg<-save_configuration(repo,f$v$version_id,parsers=saved$parsers,expected_revision=2L,actor_id="other")
  expect_equal(nextcfg$archive_settings,saved$archive_settings)
  expect_equal(get_configuration(repo,f$cfg$config_id),original)
  expect_error(approve_clarification_answer(repo,draft,TRUE),"stale")
})

test_that("plain ZIP generic relationships need explicit member and key approval", {
  repo<-new_test_repo();f<-full_fixture(repo,plain_zip_fixture())
  cfg<-approve_zip_settings(repo,f$v$version_id,f$cfg$config_id,"Occurrence.tsv")
  cfg<-approve_zip_settings(repo,f$v$version_id,cfg$config_id,"MeasurementOrFact.tsv")
  q<-prepare_clarifications(repo,f$v$version_id,cfg$config_id)
  link<-Filter(function(q)q$type=="archive_linkage",q$questions)[[1]]
  expect_false(link$suggestions[[1]]$confirmed)
  x<-q$preparation
  d<-preview_clarification_answer(repo,q,link$question_id,list(
    core_table_id=x$tables[[1]]$table_id,extension_table_id=x$tables[[2]]$table_id,
    core_position=0,extension_position=0),"Synthetic owner declares this exact relationship","owner")
  expect_equal(q$prerequisites$linkage[[1]]$status,"not_evaluated")
  saved<-approve_clarification_answer(repo,d,TRUE)
  expect_equal(saved$validation_spec$linkage_mappings[[1]]$source,"user")
  p<-assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,saved$config_id))
  expect_equal(p$linkage[[1]]$status,"ready")
  expect_equal(p$linkage[[1]]$eligible_rows,2L)
  expect_true(all(vapply(p$dates,function(c)c$status=="not_evaluated",logical(1))))
  expect_equal(p$linkage[[1]]$scientific_rows_evaluated,0L)
  other<-open_repository(repo$root);on.exit(close_repository(other),add=TRUE)
  expect_equal(get_configuration(other,saved$config_id)$archive_settings,saved$archive_settings)
})

test_that("plain member errors, quotas, no tables and present bad descriptors stay explicit", {
  repo<-new_test_repo();f<-full_fixture(repo,plain_zip_fixture(list(
    "good.tsv"="id\tdate\n001\t2020\n","bad.csv"="a,b\n1,2,3\n","note.html"="ignored")))
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  expect_equal(vapply(x$tables,function(t)t$status,character(1)),c("complete","unreadable"))
  expect_null(x$tables[[2]]$population_count)
  limited<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id,max_table_bytes=5L)
  expect_true(all(vapply(limited$tables,function(t)t$status=="limited",logical(1))))
  stopped<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id,cancelled=function()TRUE)
  expect_true(all(vapply(stopped$tables,function(t)t$status=="cancelled",logical(1))))
  none<-full_fixture(repo,plain_zip_fixture(list("note.json"="{}")))
  x<-read_validation_tables(repo,none$v$version_id,none$cfg$config_id)
  expect_equal(x$tables[[1]]$status,"unsupported")
  bad<-full_fixture(repo,plain_zip_fixture(list("meta.xml"="<broken>","good.tsv"="id\n001\n")))
  x<-read_validation_tables(repo,bad$v$version_id,bad$cfg$config_id)
  expect_equal(x$tables[[1]]$status,"unreadable")
  expect_null(x$tables[[1]]$data)
})

test_that("approved headerless UTF16 members preserve all rows and exact strings", {
  repo<-new_test_repo()
  bytes<-c(as.raw(c(255,254)),iconv("001\tNA\r\n002\t2020\r\n",to="UTF-16LE",toRaw=TRUE)[[1]])
  f<-full_fixture(repo,plain_zip_fixture(list("nested/data.tsv"=bytes)))
  cfg<-approve_zip_settings(repo,f$v$version_id,f$cfg$config_id,"nested/data.tsv",
    list(parser=list(encoding="UTF-16LE",delimiter="\t",decimal_mark=".",quote='"'),header=FALSE))
  t<-read_validation_tables(repo,f$v$version_id,cfg$config_id)$tables[[1]]
  expect_equal(t$population_count,2L)
  expect_false(t$header_present)
  expect_equal(names(t$data),c("column_1","column_2"))
  expect_equal(t$data[[1]],c("001","002"))
  expect_equal(t$data[[2]],c("NA","2020"))
  expect_match(t$record_ids[2],":nested/data.tsv:row:2$")
})

test_that("bounded plain ZIP preview works for tables larger than the preview byte budget", {
  repo<-new_test_repo()
  data<-paste0("id\tdate\n",paste(rep("001\t2020",1000),collapse="\n"),"\n")
  f<-full_fixture(repo,plain_zip_fixture(list("large.tsv"=data)))
  x<-inspect_input(f$v$version_id,f$cfg$config_id,repo,max_preview_bytes=1024L)$resources[[1]]
  expect_length(x$tables,1L)
  expect_equal(nrow(x$tables[[1]]$preview),20L)
  expect_true(x$tables[[1]]$truncated)
  expect_match(x$diagnostic,"approval|confirmation")
  expect_equal(x$assessment_scope,"preview_only")
})

test_that("ordinary archive settings cannot reuse another member or a changed setting approval", {
  repo<-new_test_repo();f<-full_fixture(repo,plain_zip_fixture())
  cfg<-approve_zip_settings(repo,f$v$version_id,f$cfg$config_id,"Occurrence.tsv")
  settings<-cfg$archive_settings
  settings[[f$v$resource_ids[1]]][["Occurrence.tsv"]]$header<-FALSE
  changed<-save_configuration(repo,f$v$version_id,parsers=cfg$parsers,archive_settings=settings,
    expected_revision=2L,actor_id="owner")
  x<-read_validation_tables(repo,f$v$version_id,changed$config_id)
  expect_true(x$tables[[1]]$settings_pending)
  expect_null(x$tables[[1]]$population_count)
  expect_equal(x$tables[[1]]$loaded_rows,3L)
  expect_true(x$tables[[2]]$settings_pending)
  bad<-settings;names(bad)<-"foreign"
  expect_error(save_configuration(repo,f$v$version_id,archive_settings=bad,expected_revision=3L,actor_id="owner"),"resources")
  bad<-settings;names(bad[[1]])<-"../escape.tsv"
  expect_error(save_configuration(repo,f$v$version_id,archive_settings=bad,expected_revision=3L,actor_id="owner"),"members")
})

test_that("pending linkage in a sibling resource cannot reopen an approved plain ZIP relationship", {
  repo<-new_test_repo();v<-register_input(c(plain_zip_fixture(),full_archive(include_extension=FALSE)),list(),repo)
  cfg<-make_config(repo,v$version_id)
  for(member in c("Occurrence.tsv","MeasurementOrFact.tsv"))cfg<-approve_zip_settings(repo,v$version_id,cfg$config_id,member)
  q<-prepare_clarifications(repo,v$version_id,cfg$config_id)
  item<-Filter(function(q)q$type=="archive_linkage",q$questions)[[1]]
  pair<-item$suggestions[[1]]$answer
  d<-preview_clarification_answer(repo,q,item$question_id,pair,"Exact synthetic relationship","owner")
  cfg<-approve_clarification_answer(repo,d,TRUE)
  q<-prepare_clarifications(repo,v$version_id,cfg$config_id)
  expect_equal(q$prerequisites$linkage[[1]]$status,"ready")
  expect_equal(q$prerequisites$linkage[[2]]$status,"not_evaluated")
  expect_length(Filter(function(q)q$type=="archive_linkage"&&q$resource_id==v$resource_ids[1],q$questions),0L)
})

test_that("UTF16 preview prefixes ending inside surrogate pairs do not lose readable rows", {
  repo<-new_test_repo()
  text<-paste0("id\tvalue\n",paste(rep("001\t\U0001F41F",35),collapse="\n"),"\n")
  bytes<-c(as.raw(c(255,254)),iconv(text,to="UTF-16LE",toRaw=TRUE)[[1]])
  # End after a high surrogate plus one byte of its low surrogate.
  cut<-which(as.integer(bytes)==216L)[25]+1L
  f<-full_fixture(repo,plain_zip_fixture(list("unicode.tsv"=bytes)))
  x<-inspect_input(f$v$version_id,f$cfg$config_id,repo,max_preview_bytes=cut)$resources[[1]]
  expect_length(x$tables,1L)
  expect_equal(nrow(x$tables[[1]]$preview),20L)
  expect_equal(x$tables[[1]]$preview[[2]][1],"\U0001F41F")
})

test_that("present uppercase descriptor is not bypassed by the generic fallback", {
  repo<-new_test_repo();f<-full_fixture(repo,plain_zip_fixture(list("META.XML"="<broken>","good.tsv"="id\n001\n")))
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  expect_equal(x$tables[[1]]$status,"unreadable")
  expect_null(x$tables[[1]]$archive_mode)
})

test_that("ordinary ZIP upload detection does not block approved members", {
  repo<-new_test_repo();path<-plain_zip_fixture()
  v<-register_uploaded_inputs(repo,data.frame(name="upload.zip",size=file.info(path)$size,type="",datapath=path),"ZIP upload","owner")
  cfg<-approve_zip_settings(repo,v$version_id,v$config_id,"Occurrence.tsv")
  cfg<-approve_zip_settings(repo,v$version_id,cfg$config_id,"MeasurementOrFact.tsv")
  q<-prepare_clarifications(repo,v$version_id,cfg$config_id)
  expect_true(all(vapply(q$prerequisites$table_checks,function(x)x$status=="ready",logical(1))))
  date<-Filter(function(q)q$type=="date_mapping"&&q$member=="Occurrence.tsv",q$questions)[[1]]
  d<-preview_clarification_answer(repo,q,date$question_id,list(date_role="sampling_date",columns=c(value=1)),"Synthetic role","owner")
  cfg<-approve_clarification_answer(repo,d,TRUE)
  p<-assess_validation_prerequisites(read_validation_tables(repo,v$version_id,cfg$config_id))
  expect_equal(p$dates[[1]]$status,"ready")
})

test_that("bounded preview never invents a value at the byte boundary", {
  repo<-new_test_repo()
  for(text in c("id,value\n1,abcdefghij\n","id,value\n0,ok\n1,\"abcdefghij\"\n")) {
    f<-full_fixture(repo,plain_zip_fixture(list("data.csv"=text)))
    budget<-if(grepl("0,ok",text,fixed=TRUE))20L else 13L
    x<-inspect_input(f$v$version_id,f$cfg$config_id,repo,max_preview_bytes=budget)$resources[[1]]
    expect_length(x$tables,1L)
    t<-x$tables[[1]]
    expect_equal(nrow(t$preview),if(grepl("0,ok",text,fixed=TRUE))1L else 0L)
    expect_length(t$record_ids,nrow(t$preview))
    expect_false(any(t$preview[[2]]=="abc"))
    if(nrow(t$preview))expect_equal(t$preview[[2]][1],"ok")
    expect_true(t$truncated)
  }
})

test_that("unchanged settings on a damaged sibling cannot block a valid member approval", {
  repo<-new_test_repo();v<-register_input(c(plain_zip_fixture(),plain_zip_fixture()),list(),repo)
  cfg<-make_config(repo,v$version_id)
  approve_for<-function(cfg,rid) {
    q<-prepare_clarifications(repo,v$version_id,cfg$config_id)
    item<-Filter(function(q)q$type=="archive_parser"&&q$resource_id==rid&&q$member=="Occurrence.tsv",q$questions)[[1]]
    d<-preview_clarification_answer(repo,q,item$question_id,item$suggestions[[1]]$answer,"Synthetic exact settings","owner")
    approve_clarification_answer(repo,d,TRUE)
  }
  cfg<-approve_for(cfg,v$resource_ids[1])
  paths<-get_input(repo,v$version_id)$resources
  writeBin(charToRaw("tampered"),paths$owned_path[paths$resource_id==v$resource_ids[1]])
  saved<-approve_for(cfg,v$resource_ids[2])
  expect_equal(saved$revision,3L)
  expect_equal(saved$archive_settings[[v$resource_ids[1]]],cfg$archive_settings[[v$resource_ids[1]]])
  p<-assess_validation_prerequisites(read_validation_tables(repo,v$version_id,saved$config_id))
  expect_true(any(vapply(p$table_checks,function(x)x$status=="ready",logical(1))))
})

test_that("a failed quoted interpretation can propose literal TSV quotes without approval", {
  repo<-new_test_repo()
  text<-'id\tvalue\tnote\n001\t"text\tother"\n'
  f<-full_fixture(repo,plain_zip_fixture(list("literal.tsv"=text)))
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  t<-x$tables[[1]]
  expect_equal(t$status,"complete")
  expect_equal(t$proposed_setting$parser$quote,"")
  expect_true(t$settings_pending)
  expect_null(t$population_count)
  expect_equal(t$data[[2]],'"text')
  expect_equal(t$data[[3]],'other"')
  expect_match(t$detection$message,"[Ll]iteral|enclosure")
  # An explicit existing setting is never silently replaced.
  settings<-stats::setNames(list(stats::setNames(list(list(parser=default_parser("literal.tsv"),header=TRUE)),"literal.tsv")),f$v$resource_ids[1])
  cfg<-save_configuration(repo,f$v$version_id,archive_settings=settings,expected_revision=1L,actor_id="owner")
  t<-read_validation_tables(repo,f$v$version_id,cfg$config_id)$tables[[1]]
  expect_equal(t$status,"unreadable")
  expect_equal(t$proposed_setting$parser$quote,'"')
})

test_that("UTF8 members without a BOM do not gain phantom trailing records", {
  repo<-new_test_repo()
  text<-"id\tname\n001\tcaf\u00e9\U0001F41F\n002\tcr\u00e8me\n"
  f<-full_fixture(repo,plain_zip_fixture(list("unicode.tsv"=text)))
  t<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)$tables[[1]]
  expect_equal(t$status,"complete")
  expect_equal(t$loaded_rows,2L)
  expect_equal(t$data[[2]],c("caf\u00e9\U0001F41F","cr\u00e8me"))
  records<-lexical_records(rawToChar(charToRaw(text)),default_parser("unicode.tsv"),100L)
  expect_length(records,3L)
  expect_true(all(lengths(records)==2L))
})
