# Verify the supplied tab-separated Venezia CSV through a registered local copy.
extra<-Sys.getenv("ECODATA_R_LIBRARY")
if(nzchar(extra)).libPaths(c(extra,.libPaths()))
pkgload::load_all(".",quiet=TRUE)
source<-Sys.getenv("ECODATA_DATE_INPUT")
if(!nzchar(source)||!file.exists(source))stop("Set ECODATA_DATE_INPUT to the supplied Venezia CSV")
root<-Sys.getenv("ECODATA_TWO_DIGIT_ROOT",file.path(Sys.getenv("LOCALAPPDATA"),"ecodata","two-digit-year-review-20261127"))
if(dir.exists(root))stop("Choose a new ECODATA_TWO_DIGIT_ROOT; existing runtimes are preserved")
before<-digest::digest(file=source,algo="sha256",serialize=FALSE)
r<-open_repository(root)
v<-register_uploaded_inputs(r,data.frame(name=basename(source),size=file.info(source)$size,
  type="text/csv",datapath=source),"Venezia two-digit date verification","format-verification")
cfg<-get_configuration(r,v$config_id)
stopifnot(cfg$parsers[[v$resource_ids[1]]]$encoding=="UTF-16LE",
  cfg$parsers[[v$resource_ids[1]]]$delimiter=="\t")
request<-get("prepare_date_information",asNamespace("ecodata"))(r,v$version_id,cfg$config_id)
table<-request$preparation$tables[[1]]
position<-match("DATA PRELIEVO",unlist(table$schema$headers))-1L
stopifnot(!is.na(position),nrow(table$data)==468L)
hint<-request$date_fields[[1]]$fields[[position+1L]]
stopifnot(identical(hint$selected,"dmy-slash-yy"))
cfg<-get("save_date_declarations",asNamespace("ecodata"))(r,request,
  list(list(table_id=table$table_id,columns=c(value=position),pattern_id=hint$selected)),"format-verification")
op<-submit_validation_run(r,v$version_id,cfg$config_id,"format-verification","two-digit-year-acceptance",families="dates")
start_validation_worker(r,op$operation_id)
deadline<-proc.time()[["elapsed"]]+600
repeat {
  refresh_validation_workers(r);run<-get_validation_run(r,op$operation_id)
  if(!run$status%in%c("queued","running"))break
  if(proc.time()[["elapsed"]]>deadline)stop("Validation did not complete within 600 seconds")
  Sys.sleep(.2)
}
s<-get_validation_summary(r,op$operation_id)
stopifnot(run$status=="completed",s$date_counts$recognised==468L,
  s$date_counts$unrecognised==0L,s$date_counts$missing==0L,verify_input(r,v$version_id)$ok,
  identical(before,digest::digest(file=source,algo="sha256",serialize=FALSE)))
rows<-query_validation_details(r,op$operation_id,"dates",page_size=1)$records
stopifnot(rows[[1]]$original_values$value=="17/05/11")
payload<-get_validation_result(r,op$operation_id)
close_repository(r);r<-open_repository(root)
stopifnot(identical(payload,get_validation_result(r,op$operation_id)))
result<-list(root=root,operation_id=op$operation_id,column="DATA PRELIEVO",format="DD/MM/YY",
  century="unspecified",status=run$status,date_counts=s$date_counts,
  original_unchanged=TRUE,restart_identical=TRUE)
dir.create("evidence/two-digit-years",recursive=TRUE,showWarnings=FALSE)
jsonlite::write_json(result,"evidence/two-digit-years/manual-result.json",auto_unbox=TRUE,pretty=TRUE)
print(result);close_repository(r)
