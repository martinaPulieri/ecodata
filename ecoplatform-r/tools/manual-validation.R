# Task 2E acceptance: persistent background validation, restart and removal.
# Run from ecoplatform-r/. Choose a NEW local ECODATA_VALIDATION_ROOT to keep
# the demo for a Shiny session; the default is an isolated temporary runtime.
.libPaths(c(Sys.getenv("ECODATA_R_LIBRARY"),.libPaths()))
pkgload::load_all(".",quiet=TRUE)
runtime<-Sys.getenv("ECODATA_VALIDATION_ROOT",unset=tempfile("ecodata-validation-"))
if(dir.exists(runtime))stop("Choose a new demo runtime; existing data is never overwritten")
repo<-open_repository(runtime)
stage<-file.path(repo$root,"tmp","synthetic-input");dir.create(stage)
writeLines(c('<archive xmlns="http://rs.tdwg.org/dwc/text/">',
 '<core rowType="http://rs.tdwg.org/dwc/terms/Occurrence" fieldsTerminatedBy="," ignoreHeaderLines="1"><files><location>core.csv</location></files><id index="0"/><field index="1" term="http://rs.tdwg.org/dwc/terms/occurrenceID"/><field index="2" term="http://rs.tdwg.org/dwc/terms/eventDate"/></core>',
 '<extension rowType="http://rs.tdwg.org/dwc/terms/MeasurementOrFact" fieldsTerminatedBy="," ignoreHeaderLines="1"><files><location>measurements.csv</location></files><coreid index="0"/></extension></archive>'),file.path(stage,"meta.xml"))
writeLines(c("id,occurrenceID,Date observed","001,obs-a,2020-03-15","DUP,obs-b,2020-02-30",
 "DUP,obs-c,03/04/2020",",obs-d,","NA,obs-e,2020"," space,obs-f,spring 2020",
 "unused,obs-g,2020-03-15/2020-03-20"),file.path(stage,"core.csv"))
writeLines(c("coreid,value","001,1","001,2","DUP,3",",4","missing,5","NA,6","001 ,7"," space,8","1,9"),file.path(stage,"measurements.csv"))
path<-file.path(stage,"synthetic-validation.zip")
zip::zipr(path,c("meta.xml","core.csv","measurements.csv"),root=stage)
original_hash<-hash_file(path)
v<-register_input(path,list(title="Task 2E — synthetic validation demo"),repo)
cfg<-save_configuration(repo,v$version_id,actor_id="acceptance-synthetic")
op<-submit_validation_run(repo,v$version_id,cfg$config_id,"acceptance-synthetic","synthetic-run-1",0L)
start_validation_worker(repo,op$operation_id)
deadline<-proc.time()[["elapsed"]]+120
repeat {
  refresh_validation_workers(repo)
  run<-get_validation_run(repo,op$operation_id)
  if(!run$status%in%c("queued","running"))break
  if(proc.time()[["elapsed"]]>deadline)stop("Worker timeout; runtime preserved for inspection")
  Sys.sleep(.1)
}
result<-get_validation_result(repo,op$operation_id)
if(is.null(result))stop("Worker failed: ",utils::tail(run$events$reason,1))
summary<-get_validation_summary(repo,op$operation_id)
stopifnot(run$status=="completed_with_limitations",summary$date_counts$recognised==4L,
 summary$date_counts$ambiguous==1L,summary$date_counts$missing==1L,summary$date_counts$unrecognised==1L,
 summary$linkage_counts$linked==4L,summary$linkage_counts$ambiguous==1L,
 summary$linkage_counts$missing_reference==1L,summary$linkage_counts$unresolved_reference==3L,
 query_validation_details(repo,op$operation_id,"dates")$total==7L,
 query_validation_details(repo,op$operation_id,"linkage")$total==9L,
 query_validation_details(repo,op$operation_id,"findings")$total==10L,
 query_validation_details(repo,op$operation_id,"dates",page=2L,page_size=3L)$records[[1]]$row_number==4L,
 verify_input(repo,v$version_id)$ok,hash_file(path)==original_hash,run$claim$pid!=Sys.getpid())
set_workspace_state(repo,v$version_id,"removed",0L,"demo-remove","acceptance-synthetic")
stopifnot(identical(get_validation_result(repo,op$operation_id),result))
set_workspace_state(repo,v$version_id,"active",1L,"demo-restore","acceptance-synthetic")
new_config<-save_configuration(repo,v$version_id,actor_id="acceptance-synthetic",expected_revision=1L,
 metadata=list(note="New configuration created after the saved assessment"))
stopifnot(identical(get_validation_result(repo,op$operation_id),result))
close_repository(repo);repo<-open_repository(runtime)
stopifnot(identical(get_validation_result(repo,op$operation_id),result),verify_input(repo,v$version_id)$ok,
 get_validation_run(repo,op$operation_id)$frozen$config_id==cfg$config_id,
 nrow(list_validation_runs(repo))==1L,nrow(list_workspace_events(repo,v$version_id))==2L)
evidence<-list(runtime=repo$root,operation_id=op$operation_id,version_id=v$version_id,
 saved_config_id=cfg$config_id,current_config_id=new_config$config_id,status=run$status,
 date_counts=summary$date_counts,linkage_counts=summary$linkage_counts,date_rows=7L,linkage_rows=9L,findings=10L,
 finding_targets=DBI::dbGetQuery(repo$con,"SELECT count(*) AS n FROM validation_finding_targets")$n,
 restart_identical=TRUE,retained_after_removal=TRUE,retained_after_configuration_change=TRUE,
 source_hash_unchanged=TRUE,worker_pid=run$claim$pid,schema=3L)
dir.create("evidence/shiny-validation",recursive=TRUE,showWarnings=FALSE)
writeLines(json_text(result),"evidence/shiny-validation/synthetic-result.json")
jsonlite::write_json(evidence,"evidence/shiny-validation/manual-result.json",pretty=TRUE,auto_unbox=TRUE)
close_repository(repo)
cat("Schema v3; background worker completed with disclosed limitations.\n")
cat("Dates: 7 saved rows -> recognised4, ambiguous1, missing1, unrecognised1.\n")
cat("Linkage: 9 saved rows -> linked4, ambiguous1, missing1, unresolved3; 10 findings.\n")
cat("Measurement table has no confirmed date role: explicitly not evaluated.\n")
cat("Identical saved result after removal, restoration, configuration revision and restart; original unchanged.\n")
cat("Runtime:",runtime,"\nRun:",op$operation_id,"\n")
