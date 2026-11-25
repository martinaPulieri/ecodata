test_that("full reading scans beyond previews and preserves original text and identities", {
  repo <- new_test_repo()
  text <- paste0('id,value,value\n',paste(sprintf('%03d,NA,"line1\r\nline2"',1:35),collapse='\n'),'\n')
  f <- full_fixture(repo,write_fixture(text))
  before <- get_input(repo,f$v$version_id)$resources$sha256
  x <- read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  table <- x$tables[[1]]
  expect_equal(table$status,"complete")
  expect_equal(table$population_count,35L)
  expect_equal(nrow(table$data),35L)
  expect_identical(names(table$data),c("id","value","value"))
  expect_equal(table$data[[1]][1],"001")
  expect_equal(table$data[[2]][35],"NA")
  expect_equal(table$data[[3]][1],"line1\r\nline2")
  expect_match(table$record_ids[[35]],":row:35$")
  expect_equal(nrow(inspect_input(f$v$version_id,f$cfg$config_id,repo)$resources[[1]]$tables[[1]]$preview),20L)
  expect_equal(get_input(repo,f$v$version_id)$resources$sha256,before)
  expect_false(x$scientific_checks_executed)
  expect_equal(nrow(list_operations(repo)),0L)
})

test_that("late malformed records fail independently from readable sibling resources", {
  repo <- new_test_repo()
  bad <- write_fixture(paste0("id,date\n",paste(rep("001,2020",30),collapse="\n"),"\n002,2020,extra\n"))
  good <- write_fixture("data_campionamento,data_analisi\n2020-03-15,03/04/2020\n")
  v <- register_input(c(bad,good),list(),repo); cfg <- make_config(repo,v$version_id)
  x <- read_validation_tables(repo,v$version_id,cfg$config_id)
  expect_equal(vapply(x$tables,function(t)t$status,character(1)),c("unreadable","complete"))
  expect_null(x$tables[[1]]$population_count)
  p <- assess_validation_prerequisites(x)
  expect_equal(length(p$date_suggestions),2L)
  expect_true(all(vapply(p$date_suggestions,function(m)!m$confirmed,logical(1))))
  expect_true(all(vapply(p$dates,function(d)d$status=="not_evaluated",logical(1))))
})

test_that("quotas and cancellation never claim a complete population", {
  repo <- new_test_repo(); f <- full_fixture(repo,write_fixture("id,date\n001,2020\n002,2021\n003,2022\n"))
  rows <- read_validation_tables(repo,f$v$version_id,f$cfg$config_id,max_rows=1L)$tables[[1]]
  expect_equal(rows$status,"limited"); expect_null(rows$population_count);expect_equal(nrow(rows$data),1L)
  bytes <- read_validation_tables(repo,f$v$version_id,f$cfg$config_id,max_table_bytes=5L)$tables[[1]]
  expect_equal(bytes$status,"limited");expect_null(bytes$population_count)
  cells <- read_validation_tables(repo,f$v$version_id,f$cfg$config_id,max_cells=3L)$tables[[1]]
  expect_equal(cells$status,"limited");expect_null(cells$population_count)
  stopped <- read_validation_tables(repo,f$v$version_id,f$cfg$config_id,cancelled=function()TRUE)$tables[[1]]
  expect_equal(stopped$status,"cancelled");expect_null(stopped$population_count)
  expect_equal(assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,f$cfg$config_id,max_rows=1))$dates[[1]]$status,"not_evaluated")
})

test_that("descriptor indices resolve core key zero separately from occurrenceID", {
  repo <- new_test_repo(); f <- full_fixture(repo,full_archive())
  x <- read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  p <- assess_validation_prerequisites(x)
  expect_equal(p$linkage[[1]]$status,"ready")
  expect_equal(p$linkage[[1]]$mapping$core$column$position,0L)
  expect_equal(p$linkage[[1]]$mapping$core$column$original_header,"id")
  expect_equal(p$linkage[[1]]$mapping$extension$column$position,0L)
  expect_equal(p$dates[[1]]$status,"ready")
  expect_equal(p$dates[[1]]$mapping$columns$value$position,2L)
  expect_equal(p$dates[[1]]$mapping$columns$value$original_header,"Date observed")
  expect_equal(p$dates[[1]]$eligible_rows,2L)
  expect_false(p$scientific_checks_executed)
})

test_that("unreadable or missing extensions do not disable readable declared dates", {
  repo <- new_test_repo()
  for(path in c(full_archive(extension="coreid,value\n001,1,extra\n"),full_archive(include_extension=FALSE))) {
    f <- full_fixture(repo,path)
    p <- assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,f$cfg$config_id))
    expect_equal(p$linkage[[1]]$status,"not_evaluated")
    expect_match(p$linkage[[1]]$reason,"measurement|extension|member",ignore.case=TRUE)
    expect_equal(p$dates[[1]]$status,"ready")
    expect_equal(p$dates[[1]]$eligible_rows,2L)
  }
})

test_that("required key and date index prerequisites stay independent", {
  repo <- new_test_repo()
  base <- full_archive(); entries <- utils::unzip(base,list=TRUE)
  con <- unz(base,"meta.xml","rb"); xml <- rawToChar(readBin(con,"raw",n=1e6));close(con)
  bad_key <- sub('<id index="0"','<id index="99"',xml,fixed=TRUE)
  f <- full_fixture(repo,full_archive(descriptor=bad_key))
  p <- assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,f$cfg$config_id))
  expect_equal(p$linkage[[1]]$status,"not_evaluated");expect_match(p$linkage[[1]]$reason,"index|position")
  expect_equal(p$dates[[1]]$status,"ready")
  bad_date <- sub('<field index="2"','<field index="99"',xml,fixed=TRUE)
  f <- full_fixture(repo,full_archive(descriptor=bad_date))
  p <- assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,f$cfg$config_id))
  expect_equal(p$linkage[[1]]$status,"ready")
  expect_true(any(vapply(p$dates,function(d)d$status=="not_evaluated",logical(1))))
})

test_that("saved mapping schemas are verified and unrelated mappings remain usable", {
  repo <- new_test_repo(); v <- register_input(write_fixture("anno,giorno,mese,data_analisi\n2020,7,03,2020\n"),list(),repo)
  table <- new_validation_table(v$version_id,v$resource_ids[1],c("anno","giorno","mese","data_analisi"))
  sampling <- new_date_mapping(table,"sampling","sampling_date",c(year=0,day=1,month=2),"user","tester","Confirmed",TRUE)
  analysis <- new_date_mapping(table,"analysis","analysis_date",c(value=3),"suggested","detector","Not confirmed")
  cfg <- make_config(repo,v$version_id,validation_spec=new_validation_spec(list(sampling,analysis)))
  p <- assess_validation_prerequisites(read_validation_tables(repo,v$version_id,cfg$config_id))
  expect_equal(vapply(p$dates,function(d)d$status,character(1)),c("ready","not_evaluated"))
  altered <- new_validation_table(v$version_id,v$resource_ids[1],c("wrong","giorno","mese","data_analisi"))
  invalid <- new_date_mapping(altered,"sampling","sampling_date",c(year=0,day=1,month=2),"user","tester","Wrong headers",TRUE)
  cfg <- make_config(repo,v$version_id,expected_revision=1L,validation_spec=new_validation_spec(list(invalid)))
  p <- assess_validation_prerequisites(read_validation_tables(repo,v$version_id,cfg$config_id))
  expect_equal(p$dates[[1]]$status,"not_evaluated");expect_match(p$dates[[1]]$reason,"schema|header")
})

test_that("header-only and UTF16 inputs retain exact populations and lexical values", {
  repo <- new_test_repo(); f <- full_fixture(repo,write_fixture("id,date\n"))
  table <- read_validation_tables(repo,f$v$version_id,f$cfg$config_id)$tables[[1]]
  expect_equal(table$population_count,0L);expect_length(table$record_ids,0L)
  path <- tempfile(fileext=".csv");writeBin(c(as.raw(c(255,254)),iconv("id\tdate\n001\tNA\n",to="UTF-16LE",toRaw=TRUE)[[1]]),path)
  upload <- data.frame(name="utf16.csv",size=file.info(path)$size,type="text/csv",datapath=path)
  v <- register_uploaded_inputs(repo,upload,"UTF16","tester")
  table <- read_validation_tables(repo,v$version_id,v$config_id)$tables[[1]]
  expect_identical(table$data[[1]],"001");expect_identical(table$data[[2]],"NA")
})

test_that("descriptor settings and headerless data preserve positional identity", {
  repo<-new_test_repo()
  xml<-paste0('<archive xmlns="http://rs.tdwg.org/dwc/text/">',
    '<core rowType="http://rs.tdwg.org/dwc/terms/Occurrence" fieldsTerminatedBy="\\t" fieldsEnclosedBy="" ignoreHeaderLines="0" linesTerminatedBy="\\r\\n"><files><location>core.csv</location></files><id index="0"/><field index="1" term="http://rs.tdwg.org/dwc/terms/eventDate"/></core></archive>')
  # XML attribute escapes contain one literal backslash as in a DwC-A descriptor.
  xml<-gsub("\\\\","\\",xml,fixed=TRUE)
  f<-full_fixture(repo,full_archive(core="001\t2020\r\nNA\t03/04/2020\r\n",descriptor=xml))
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  expect_equal(x$tables[[1]]$population_count,2L)
  expect_false(x$tables[[1]]$header_present)
  expect_equal(names(x$tables[[1]]$data),c("column_1","column_2"))
  expect_equal(x$tables[[1]]$data[[1]],c("001","NA"))
  expect_equal(assess_validation_prerequisites(x)$dates[[1]]$status,"ready")
})

test_that("unsupported descriptor namespaces and unsafe declarations cannot become usable", {
  repo<-new_test_repo()
  base<-full_archive();con<-unz(base,"meta.xml","rb");xml<-rawToChar(readBin(con,"raw",n=1e6));close(con)
  foreign<-sub('http://rs.tdwg.org/dwc/text/','http://unrelated.example/schema/',xml,fixed=TRUE)
  f<-full_fixture(repo,full_archive(descriptor=foreign))
  p<-assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,f$cfg$config_id))
  expect_false(any(vapply(p$linkage,function(x)x$status=="ready",logical(1))))
  expect_false(any(vapply(p$dates,function(x)x$status=="ready",logical(1))))
  unsafe<-sub('<location>core.csv</location>','<location>../core.csv</location>',xml,fixed=TRUE)
  f<-full_fixture(repo,full_archive(descriptor=unsafe))
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  expect_equal(x$tables[[1]]$status,"unreadable");expect_match(x$tables[[1]]$reason,"unsafe")
})

test_that("saved linkage cannot replace the descriptor key with occurrenceID", {
  repo<-new_test_repo();v<-register_input(full_archive(),list(),repo)
  core<-new_validation_table(v$version_id,v$resource_ids[1],c("id","occurrenceID","Date observed"),"core.csv")
  ext<-new_validation_table(v$version_id,v$resource_ids[1],c("coreid","value"),"measurements.csv")
  wrong<-new_linkage_mapping(core,1,ext,0,"wrong","tester","Incorrect key",TRUE)
  date<-new_date_mapping(core,"date","analysis_date",c(value=2),"descriptor","tester","Incorrect role",TRUE)
  cfg<-make_config(repo,v$version_id,validation_spec=new_validation_spec(list(date),list(wrong)))
  p<-assess_validation_prerequisites(read_validation_tables(repo,v$version_id,cfg$config_id))
  expect_equal(p$linkage[[1]]$status,"not_evaluated");expect_match(p$linkage[[1]]$reason,"indices")
  expect_equal(p$dates[[1]]$status,"not_evaluated");expect_match(p$dates[[1]]$reason,"role")
})

test_that("mid-scan cancellation and damaged sources cannot yield usable prerequisites", {
  repo<-new_test_repo();f<-full_fixture(repo,write_fixture(paste0("id,date\n",paste(rep("001,2020",1000),collapse="\n"))))
  ticks<-0L;cancel<-function(){ticks<<-ticks+1L;ticks>=3L}
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id,cancelled=cancel)
  expect_equal(x$tables[[1]]$status,"cancelled")
  expect_null(x$tables[[1]]$population_count)
  path<-get_input(repo,f$v$version_id)$resources$owned_path
  writeBin(charToRaw("altered"),path)
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  expect_equal(x$tables[[1]]$status,"unreadable");expect_match(x$tables[[1]]$reason,"integrity")
  expect_error(read_validation_tables(repo,"unknown",f$cfg$config_id),"different version")
})

test_that("missing extension location and small member quotas preserve readable core", {
  repo<-new_test_repo()
  base<-full_archive();con<-unz(base,"meta.xml","rb");xml<-rawToChar(readBin(con,"raw",n=1e6));close(con)
  missing<-sub("<location>measurements.csv</location>","",xml,fixed=TRUE)
  f<-full_fixture(repo,full_archive(descriptor=missing))
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  p<-assess_validation_prerequisites(x)
  expect_equal(length(x$tables),2L)
  expect_equal(x$tables[[1]]$status,"complete")
  expect_equal(p$dates[[1]]$status,"ready")
  expect_equal(p$linkage[[1]]$status,"not_evaluated")
  f<-full_fixture(repo,full_archive())
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id,max_table_bytes=160)
  expect_equal(vapply(x$tables,function(t)t$status,character(1)),c("complete","complete"))
})

test_that("separate saved date roles do not suppress descriptor eventDate", {
  repo<-new_test_repo()
  f<-full_fixture(repo,full_archive(core="id,occurrenceID,Date observed,analysis\n001,obs-a,2020,2021\n"))
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  analysis<-new_date_mapping(x$tables[[1]]$schema,"analysis","analysis_date",c(value=3),"user","tester","Separate explicit role",TRUE)
  cfg<-make_config(repo,f$v$version_id,expected_revision=1L,validation_spec=new_validation_spec(list(analysis)))
  p<-assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,cfg$config_id))
  core<-Filter(function(d)identical(d$table_id,x$tables[[1]]$table_id),p$dates)
  expect_length(core,2L)
  expect_true(all(vapply(core,function(d)d$status=="ready",logical(1))))
  expect_setequal(vapply(core,function(d)d$mapping$date_role,character(1)),c("analysis_date","eventDate"))
})

test_that("missing measurement profile has no invented extension population", {
  repo<-new_test_repo()
  base<-full_archive();con<-unz(base,"meta.xml","rb");xml<-rawToChar(readBin(con,"raw",n=1e6));close(con)
  xml<-sub("http://rs.tdwg.org/dwc/terms/MeasurementOrFact","http://example.org/Unsupported",xml,fixed=TRUE)
  f<-full_fixture(repo,full_archive(descriptor=xml))
  p<-assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,f$cfg$config_id))
  expect_equal(p$linkage[[1]]$status,"not_evaluated")
  expect_null(p$linkage[[1]]$table_id)
  expect_null(p$linkage[[1]]$population_count)
})

test_that("duplicate descriptor date positions cannot duplicate a ready mapping", {
  repo<-new_test_repo()
  base<-full_archive();con<-unz(base,"meta.xml","rb");xml<-rawToChar(readBin(con,"raw",n=1e6));close(con)
  field<-'<field index="2" term="http://rs.tdwg.org/dwc/terms/eventDate"/>'
  xml<-sub(field,paste0(field,field),xml,fixed=TRUE)
  f<-full_fixture(repo,full_archive(descriptor=xml))
  p<-assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,f$cfg$config_id))
  core<-Filter(function(d)grepl(":core.csv$",d$table_id),p$dates)
  expect_length(core,1L)
  expect_equal(core[[1]]$status,"not_evaluated")
  expect_match(core[[1]]$reason,"[Aa]mbiguous|[Dd]uplicate")
  expect_equal(p$linkage[[1]]$status,"ready")
})

test_that("descriptor quota is explicit and saved descriptor mappings reject duplicate fields", {
  repo<-new_test_repo()
  base<-full_archive();con<-unz(base,"meta.xml","rb");xml<-rawToChar(readBin(con,"raw",n=1e6));close(con)
  large<-sub("</archive>",paste0("<!--",strrep("x",1024^2),"--></archive>"),xml,fixed=TRUE)
  f<-full_fixture(repo,full_archive(descriptor=large))
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  expect_equal(x$tables[[1]]$status,"limited")
  expect_null(x$tables[[1]]$population_count)
  expect_match(x$tables[[1]]$reason,"metadata quota")
  field<-'<field index="2" term="http://rs.tdwg.org/dwc/terms/eventDate"/>'
  f<-full_fixture(repo,full_archive(descriptor=sub(field,paste0(field,field),xml,fixed=TRUE)))
  x<-read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
  mapping<-new_date_mapping(x$tables[[1]]$schema,"declared","eventDate",c(value=2),"descriptor","tester","Duplicate source declaration",TRUE)
  cfg<-make_config(repo,f$v$version_id,expected_revision=1L,validation_spec=new_validation_spec(list(mapping)))
  p<-assess_validation_prerequisites(read_validation_tables(repo,f$v$version_id,cfg$config_id))
  expect_equal(p$dates[[1]]$status,"not_evaluated")
  expect_equal(p$linkage[[1]]$status,"ready")
})
