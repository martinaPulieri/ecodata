# Isolated acceptance. Real Venezia questions remain pending: the script never
# invents or approves semantic answers for research data. Approval below uses
# only explicitly defined synthetic fields and a test operator.
.libPaths(c(Sys.getenv("ECODATA_R_LIBRARY"),.libPaths()))
pkgload::load_all(".",quiet=TRUE)
runtime<-Sys.getenv("ECODATA_CLARIFICATIONS_ROOT",unset=tempfile("ecodata-clarifications-"))
if(dir.exists(runtime))stop("Choose a new runtime; never overwrite an existing workspace")
repo<-open_repository(runtime)
examples<-Sys.getenv("ECODATA_EXAMPLES",unset=normalizePath("../../../data_examples",winslash="/"))
path<-list.files(examples,pattern="VE_12_ACTRMO0038.*[.]csv$",full.names=TRUE)
if(length(path)!=1L)stop("Set ECODATA_EXAMPLES to the data_examples directory")
hash<-digest::digest(path,file=TRUE,algo="sha256",serialize=FALSE)
upload<-data.frame(name=basename(path),size=file.info(path)$size,type="",datapath=path)
real<-register_uploaded_inputs(repo,upload,"Venezia - richieste da confermare","acceptance-reader")
questions<-prepare_clarifications(repo,real$version_id,real$config_id)
dates<-Filter(function(q)q$type=="date_mapping",questions$questions)
stopifnot(length(dates)==2L,nrow(list_configurations(repo,real$version_id))==1L,
  length(clarification_receipts(get_configuration(repo,real$config_id)))==0L)
real_summary<-list(version_id=real$version_id,config_id=real$config_id,
  rows=questions$preparation$tables[[1]]$population_count,
  columns=ncol(questions$preparation$tables[[1]]$data),
  pending_date_questions=length(dates),suggestions_approved=FALSE,
  approved_answers=0L,configuration_revisions=1L)
stage<-tempfile(fileext=".csv")
writeLines(c("anno,giorno,mese,data_analisi","2020,7,03,03/04/2020"),stage)
v<-register_uploaded_inputs(repo,data.frame(name="synthetic-known-roles.csv",size=file.info(stage)$size,type="",datapath=stage),
  "Esempio sintetico - ruoli dichiarati","acceptance-synthetic")
cfg<-get_configuration(repo,v$config_id)
original<-cfg$context_hash
q<-prepare_clarifications(repo,v$version_id,v$config_id)
split<-Filter(function(q)q$type=="date_mapping"&&length(q$mapping$columns)==3L,q$questions)[[1]]
draft<-preview_clarification_answer(repo,q,split$question_id,
  list(date_role="sampling_date",columns=c(year=0,day=1,month=2)),
  "Synthetic fixture explicitly declares these component roles","acceptance-synthetic")
stopifnot(nrow(list_configurations(repo,v$version_id))==1L)
rejected<-try(approve_clarification_answer(repo,draft,FALSE),silent=TRUE)
stopifnot(inherits(rejected,"try-error"),nrow(list_configurations(repo,v$version_id))==1L)
saved<-approve_clarification_answer(repo,draft,TRUE)
stopifnot(saved$revision==2L,saved$clarifications[[1]]$approved,
  identical(get_configuration(repo,v$config_id)$context_hash,original))
after<-prepare_clarifications(repo,v$version_id,saved$config_id)
stopifnot(length(Filter(function(q)q$type=="date_mapping",after$questions))==1L,
  sum(vapply(after$prerequisites$dates,function(x)x$status=="ready",logical(1)))==1L,
  all(vapply(after$prerequisites$dates,function(x)x$scientific_rows_evaluated==0L,logical(1))))
receipt<-saved$clarifications[[1]]
close_repository(repo);repo<-open_repository(runtime)
stopifnot(identical(get_configuration(repo,saved$config_id)$clarifications,saved$clarifications),
  identical(hash,digest::digest(path,file=TRUE,algo="sha256",serialize=FALSE)),
  verify_input(repo,real$version_id)$ok,nrow(list_operations(repo))==0L)
close_repository(repo)
dir.create("evidence/clarifications",recursive=TRUE,showWarnings=FALSE)
result<-list(runtime=runtime,real_venezia=real_summary,synthetic=list(
  version_id=v$version_id,configuration_revisions=2L,draft_writes=0L,
  rejected_without_approval=TRUE,approved_receipt=receipt,
  other_date_still_pending=TRUE,restart_preserved_answer=TRUE),
  original_source_unchanged=TRUE,scientific_rows_evaluated=0L,operations_created=0L)
jsonlite::write_json(result,"evidence/clarifications/manual-result.json",auto_unbox=TRUE,pretty=TRUE,null="null")
cat("Venezia: ",real_summary$rows," x ",real_summary$columns,
  "; 2 date questions pending; zero approved answers; revision 1.\n",sep="")
cat("Synthetic: review/cancel writes 0; explicit approval -> revision 2; other date pending.\n")
cat("Receipt survives reopen; original hashes unchanged; zero scientific rows/operations.\n")
cat("Runtime: ",runtime,"\n",sep="")
