# Verify the explicitly supplied delimited text without editing or renaming it.
extra<-Sys.getenv("ECODATA_R_LIBRARY")
if(nzchar(extra)).libPaths(c(extra,.libPaths()))
pkgload::load_all(".",quiet=TRUE)
source<-Sys.getenv("ECODATA_DATE_INPUT")
if(!nzchar(source)||!file.exists(source))stop("Set ECODATA_DATE_INPUT to the supplied TXT")
root<-Sys.getenv("ECODATA_TXT_ROOT",file.path(Sys.getenv("LOCALAPPDATA"),"ecodata","delimited-txt-review-20261127"))
if(dir.exists(root))stop("Choose a new ECODATA_TXT_ROOT; existing runtimes are preserved")
before<-digest::digest(file=source,algo="sha256",serialize=FALSE)
r<-open_repository(root)
v<-register_uploaded_inputs(r,data.frame(name=basename(source),size=file.info(source)$size,
  type="text/plain",datapath=source),"Delimited TXT verification","format-verification")
cfg<-get_configuration(r,v$config_id);rid<-v$resource_ids[1]
stopifnot(cfg$parser_detection[[rid]]$status=="detected",
  cfg$parsers[[rid]]$encoding=="UTF-8",cfg$parsers[[rid]]$delimiter==",")
preview<-run_workspace_inspection(r,v$version_id,cfg$config_id,"format-verification")
stopifnot(preview$inspection$resources[[1]]$status=="ready")
request<-get("prepare_date_information",asNamespace("ecodata"))(r,v$version_id,cfg$config_id)
table<-request$preparation$tables[[1]]
position<-match("eventDate",unlist(table$schema$headers))-1L
stopifnot(!is.na(position),nrow(table$data)==314L,ncol(table$data)==34L)
cfg<-get("save_date_declarations",asNamespace("ecodata"))(r,request,
  list(list(table_id=table$table_id,columns=c(value=position),pattern_id="ymd-dash")),"format-verification")
op<-submit_validation_run(r,v$version_id,cfg$config_id,"format-verification","txt-acceptance",families="dates")
start_validation_worker(r,op$operation_id)
deadline<-proc.time()[["elapsed"]]+600
repeat {
  refresh_validation_workers(r);run<-get_validation_run(r,op$operation_id)
  if(!run$status%in%c("queued","running"))break
  if(proc.time()[["elapsed"]]>deadline)stop("Validation did not complete within 600 seconds")
  Sys.sleep(.2)
}
s<-get_validation_summary(r,op$operation_id)
rows<-query_validation_details(r,op$operation_id,"dates",page_size=2)$records
stopifnot(run$status=="completed",s$date_counts$recognised==313L,s$date_counts$unrecognised==1L,
  rows[[1]]$original_values$value=="2025-19-02",rows[[1]]$status=="recognised",
  rows[[2]]$original_values$value=="2025-02-19 ",rows[[2]]$status=="unrecognised",
  verify_input(r,v$version_id)$ok,identical(before,digest::digest(file=source,algo="sha256",serialize=FALSE)))
payload<-get_validation_result(r,op$operation_id)
close_repository(r);r<-open_repository(root)
stopifnot(identical(payload,get_validation_result(r,op$operation_id)))
result<-list(root=root,operation_id=op$operation_id,reading="UTF-8, comma",rows=314L,columns=34L,
  date_counts=s$date_counts,calendar_validation=FALSE,original_unchanged=TRUE,restart_identical=TRUE)
dir.create("evidence/delimited-txt",recursive=TRUE,showWarnings=FALSE)
jsonlite::write_json(result,"evidence/delimited-txt/manual-result.json",auto_unbox=TRUE,pretty=TRUE)
print(result);close_repository(r)
