# Real OBIS remains unapproved. Only explicitly defined synthetic fixture values
# are approved by this acceptance script. No research semantics are invented.
.libPaths(c(Sys.getenv("ECODATA_R_LIBRARY"),.libPaths()))
pkgload::load_all(".",quiet=TRUE)
runtime<-Sys.getenv("ECODATA_PLAIN_ZIP_ROOT",unset=tempfile("ecodata-plain-zip-"))
if(dir.exists(runtime))stop("Choose a new isolated runtime")
repo<-open_repository(runtime)
examples<-Sys.getenv("ECODATA_EXAMPLES",unset=normalizePath("../../../data_examples",winslash="/"))
path<-file.path(examples,"OBIS_VeniceLagoon.zip")
hash<-hash_file(path)
v<-register_uploaded_inputs(repo,data.frame(name=basename(path),size=file.info(path)$size,type="",datapath=path),
  "OBIS Venezia - impostazioni da approvare","acceptance-reader")
cat("Reading real OBIS tables with proposed settings...\n");flush.console()
q<-prepare_clarifications(repo,v$version_id,v$config_id)
tables<-q$preparation$tables
stopifnot(length(tables)==2L,all(vapply(tables,function(t)t$status=="complete",logical(1))),
  all(vapply(tables,function(t)t$settings_pending&&is.null(t$population_count),logical(1))),
  length(Filter(function(q)q$type=="archive_parser",q$questions))==2L,
  length(Filter(function(q)q$type=="archive_linkage",q$questions))==1L,
  nrow(list_configurations(repo,v$version_id))==1L,
  length(clarification_receipts(get_configuration(repo,v$config_id)))==0L)
preview<-inspect_input(v$version_id,v$config_id,repo)$resources[[1]]
stopifnot(length(preview$tables)==2L,all(vapply(preview$tables,function(t)nrow(t$preview)==20L,logical(1))))
real<-list(version_id=v$version_id,config_id=v$config_id,
  tables=lapply(tables,function(t)list(member=t$member,status=t$status,
    candidate_rows=t$loaded_rows,columns=ncol(t$data),assessed_population=t$population_count,
    settings_pending=t$settings_pending,proposed_setting=t$proposed_setting)),
  ignored_members=q$preparation$resources[[1]]$ignored_members,
  pending_types=as.list(vapply(q$questions,function(q)q$type,character(1))),
  approved_answers=0L,revisions=1L,preview_rows=lapply(preview$tables,function(t)nrow(t$preview)))
for(t in tables)cat(t$member,": ",t$loaded_rows," candidate rows x ",ncol(t$data),
  "; settings pending, assessed population unknown.\n",sep="")
# Small synthetic ordinary archive with declared fixture roles.
stage<-tempfile("plain-zip-manual-");dir.create(stage)
writeLines(c("id\teventDate","001\t2020","002\t03/04/2020"),file.path(stage,"Occurrence.tsv"))
writeLines(c("id\tmeasurementDeterminedDate","001\t2020","002\t2021"),file.path(stage,"MeasurementOrFact.tsv"))
archive<-file.path(stage,"synthetic.zip")
zip::zipr(archive,c("Occurrence.tsv","MeasurementOrFact.tsv"),root=stage)
synthetic<-register_uploaded_inputs(repo,data.frame(name=basename(archive),size=file.info(archive)$size,type="",datapath=archive),
  "ZIP sintetico - relazione dichiarata dal test","acceptance-synthetic")
cfg<-get_configuration(repo,synthetic$config_id)
first_hash<-cfg$context_hash
for(member in c("Occurrence.tsv","MeasurementOrFact.tsv")) {
  requests<-prepare_clarifications(repo,synthetic$version_id,cfg$config_id)
  item<-Filter(function(q)q$type=="archive_parser"&&q$member==member,requests$questions)[[1]]
  draft<-preview_clarification_answer(repo,requests,item$question_id,
    list(parser=list(encoding="UTF-8",delimiter="\t",quote='"',decimal_mark="."),header=TRUE),
    "Synthetic fixture explicitly defines UTF8 tab and header","acceptance-synthetic")
  before<-nrow(list_configurations(repo,synthetic$version_id))
  stopifnot(inherits(try(approve_clarification_answer(repo,draft,FALSE),silent=TRUE),"try-error"),
    nrow(list_configurations(repo,synthetic$version_id))==before)
  cfg<-approve_clarification_answer(repo,draft,TRUE)
}
requests<-prepare_clarifications(repo,synthetic$version_id,cfg$config_id)
date<-Filter(function(q)q$type=="date_mapping"&&q$member=="Occurrence.tsv",requests$questions)[[1]]
draft<-preview_clarification_answer(repo,requests,date$question_id,
  list(date_role="sampling_date",columns=c(value=1)),
  "Synthetic fixture explicitly declares sampling date field","acceptance-synthetic")
cfg<-approve_clarification_answer(repo,draft,TRUE)
requests<-prepare_clarifications(repo,synthetic$version_id,cfg$config_id)
item<-Filter(function(q)q$type=="archive_linkage",requests$questions)[[1]]
pair<-requests$preparation$tables
draft<-preview_clarification_answer(repo,requests,item$question_id,
  list(core_table_id=pair[[1]]$table_id,extension_table_id=pair[[2]]$table_id,core_position=0,extension_position=0),
  "Synthetic fixture explicitly declares same id relationship","acceptance-synthetic")
cfg<-approve_clarification_answer(repo,draft,TRUE)
final<-prepare_clarifications(repo,synthetic$version_id,cfg$config_id)
stopifnot(cfg$revision==5L,final$prerequisites$linkage[[1]]$status=="ready",
  final$prerequisites$dates[[1]]$status=="ready",
  any(vapply(final$prerequisites$dates,function(d)d$status=="not_evaluated",logical(1))),
  identical(get_configuration(repo,synthetic$config_id)$context_hash,first_hash))
close_repository(repo);repo<-open_repository(runtime)
stopifnot(identical(get_configuration(repo,cfg$config_id)$clarifications,cfg$clarifications),
  verify_input(repo,v$version_id)$ok,identical(hash,hash_file(path)),
  nrow(list_operations(repo))==0L)
close_repository(repo)
dir.create("evidence/plain-zip",recursive=TRUE,showWarnings=FALSE)
jsonlite::write_json(list(runtime=runtime,real_obis=real,synthetic=list(version_id=synthetic$version_id,
  revisions=5L,approved_answers=4L,linkage_ready=TRUE,core_date_ready=TRUE,
  other_date_pending=TRUE,restart_preserved=TRUE),source_unchanged=TRUE,
  scientific_rows_evaluated=0L,operations_created=0L),
  "evidence/plain-zip/manual-result.json",auto_unbox=TRUE,pretty=TRUE,null="null")
cat("Real OBIS: 20-row previews per member; no answers approved.\n")
cat("Synthetic: 4 explicit approvals -> revision 5; linkage/core date ready, other date pending.\n")
cat("Restart/source hashes verified; zero scientific rows/operations.\n")
cat("Runtime: ",runtime,"\n",sep="")
