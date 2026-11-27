# Synthetic acceptance only; refuses an existing runtime and never reads research data.
extra<-Sys.getenv("ECODATA_R_LIBRARY")
if(nzchar(extra)).libPaths(c(extra,.libPaths()))
pkgload::load_all(".",quiet=TRUE)
root<-Sys.getenv("ECODATA_DATE_WORKFLOW_ROOT",file.path(Sys.getenv("LOCALAPPDATA"),"ecodata","date-workflow-review-20261127"))
if(dir.exists(root))stop("Choose a new ECODATA_DATE_WORKFLOW_ROOT; existing runtimes are preserved")
repo<-open_repository(root)
source<-file.path(repo$root,"tmp","observations.csv")
writeBin(charToRaw(paste0("id,date_observed,date_processed\n",
  "001,15/03/2020,2020-03-17\n002,03/04/2020,2020-04-05\n",
  "003,2020-03-22,2020-05-23\n004,30/02/2020,\n",
  "005, 15/03/2020 ,2020-06-01\n006,,2020-06-02\n")),source)
v<-register_input(source,list(title="Approved date workflow - synthetic demo"),repo)
cfg<-save_configuration(repo,v$version_id,actor_id="synthetic-reviewer")
request<-get("prepare_date_information",asNamespace("ecodata"))(repo,v$version_id,cfg$config_id)
tid<-request$preparation$tables[[1]]$table_id
cfg<-get("save_date_declarations",asNamespace("ecodata"))(repo,request,list(
  list(table_id=tid,columns=c(value=1),pattern_id="dmy-slash"),
  list(table_id=tid,columns=c(value=2),pattern_id="ymd-dash")),"synthetic-reviewer")
op<-submit_validation_run(repo,v$version_id,cfg$config_id,"synthetic-reviewer","manual-date-workflow",families="dates")
start_validation_worker(repo,op$operation_id)
deadline<-proc.time()[["elapsed"]]+90
repeat {
  refresh_validation_workers(repo)
  run<-get_validation_run(repo,op$operation_id)
  if(!run$status%in%c("queued","running"))break
  if(proc.time()[["elapsed"]]>deadline)stop("Worker did not finish within 90 seconds")
  Sys.sleep(.2)
}
summary<-get_validation_summary(repo,op$operation_id)
stopifnot(summary$date_counts$recognised==8,summary$date_counts$unrecognised==2,
  summary$date_counts$missing==2,is.null(get_validation_result(repo,op$operation_id)$families$linkage),
  all(verify_input(repo,v$version_id)$resources$ok))
before<-get_validation_result(repo,op$operation_id)
close_repository(repo);repo<-open_repository(root)
stopifnot(identical(before,get_validation_result(repo,op$operation_id)))
dir.create("evidence/date-workflow",recursive=TRUE,showWarnings=FALSE)
result<-list(root=root,version_id=v$version_id,config_id=cfg$config_id,operation_id=op$operation_id,
  status=run$status,date_counts=summary$date_counts,source_unchanged=TRUE,restart_identical=TRUE)
jsonlite::write_json(result,"evidence/date-workflow/manual-result.json",auto_unbox=TRUE,pretty=TRUE)
print(result)
close_repository(repo)
