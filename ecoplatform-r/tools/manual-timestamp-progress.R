# Read the explicitly supplied source, copy into a fresh local test runtime,
# and verify timezone-unspecified recognition without editing the original.
extra<-Sys.getenv("ECODATA_R_LIBRARY")
if(nzchar(extra)).libPaths(c(extra,.libPaths()))
pkgload::load_all(".",quiet=TRUE)
source<-Sys.getenv("ECODATA_DATE_INPUT")
if(!nzchar(source)||!file.exists(source))stop("Set ECODATA_DATE_INPUT to the supplied CSV")
root<-Sys.getenv("ECODATA_TIMESTAMP_ROOT",file.path(Sys.getenv("LOCALAPPDATA"),"ecodata","timestamp-review-20261127"))
if(dir.exists(root))stop("Choose a new ECODATA_TIMESTAMP_ROOT; existing runtimes are preserved")
before<-digest::digest(file=source,algo="sha256",serialize=FALSE)
r<-open_repository(root)
v<-register_input(source,list(title="Timestamp format verification"),r)
cfg<-save_configuration(r,v$version_id,actor_id="format-verification")
request<-get("prepare_date_information",asNamespace("ecodata"))(r,v$version_id,cfg$config_id)
table<-request$preparation$tables[[1]]
position<-match("DATA PRELIEVO",unlist(table$schema$headers))-1L
stopifnot(!is.na(position),nrow(table$data)==42L)
hint<-request$date_fields[[1]]$fields[[position+1L]]
stopifnot(identical(hint$selected,"timestamp-no-zone"))
cfg<-get("save_date_declarations",asNamespace("ecodata"))(r,request,
  list(list(table_id=table$table_id,columns=c(value=position),pattern_id=hint$selected)),"format-verification")
op<-submit_validation_run(r,v$version_id,cfg$config_id,"format-verification","timestamp-acceptance",families="dates")
start_validation_worker(r,op$operation_id)
deadline<-proc.time()[["elapsed"]]+90
repeat {
  refresh_validation_workers(r);run<-get_validation_run(r,op$operation_id)
  if(!run$status%in%c("queued","running"))break
  if(proc.time()[["elapsed"]]>deadline)stop("Validation did not complete within 90 seconds")
  Sys.sleep(.2)
}
summary<-get_validation_summary(r,op$operation_id)
stopifnot(run$status=="completed",summary$date_counts$recognised==42L,
  summary$date_counts$unrecognised==0L,summary$date_counts$missing==0L,
  verify_input(r,v$version_id)$ok,
  identical(before,digest::digest(file=source,algo="sha256",serialize=FALSE)))
result<-get_validation_result(r,op$operation_id)
close_repository(r);r<-open_repository(root)
stopifnot(identical(result,get_validation_result(r,op$operation_id)))
evidence<-list(root=root,version_id=v$version_id,operation_id=op$operation_id,
  column="DATA PRELIEVO",format="YYYY-MM-DDTHH:mm:ss",timezone="unspecified",
  status=run$status,date_counts=summary$date_counts,original_unchanged=TRUE,restart_identical=TRUE)
dir.create("evidence/timestamp-progress",recursive=TRUE,showWarnings=FALSE)
jsonlite::write_json(evidence,"evidence/timestamp-progress/manual-result.json",auto_unbox=TRUE,pretty=TRUE)
print(evidence);close_repository(r)
