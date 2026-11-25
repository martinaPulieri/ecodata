# Step 2C manual acceptance. Run from ecoplatform-r/ with the project R library.
# Scientific outcomes below are from synthetic declared fixtures only. Real OBIS
# key comparison is a provisional diagnostic; no research mapping is approved.
.libPaths(c(Sys.getenv("ECODATA_R_LIBRARY"),.libPaths()))
pkgload::load_all(".",quiet=TRUE)
runtime<-Sys.getenv("ECODATA_LINKAGE_ROOT",unset=tempfile("ecodata-linkage-"))
if(dir.exists(runtime))stop("Choose a new isolated runtime")
repo<-open_repository(runtime)
stage<-tempfile("linkage-fixture-");dir.create(stage)
writeLines(c('<archive xmlns="http://rs.tdwg.org/dwc/text/">',
 '<core rowType="http://rs.tdwg.org/dwc/terms/Occurrence" fieldsTerminatedBy="," ignoreHeaderLines="1"><files><location>core.csv</location></files><id index="0"/><field index="1" term="http://rs.tdwg.org/dwc/terms/occurrenceID"/><field index="2" term="http://rs.tdwg.org/dwc/terms/eventDate"/></core>',
 '<extension rowType="http://rs.tdwg.org/dwc/terms/MeasurementOrFact" fieldsTerminatedBy="," ignoreHeaderLines="1"><files><location>measurements.csv</location></files><coreid index="0"/></extension></archive>'),file.path(stage,"meta.xml"))
writeLines(c("id,occurrenceID,Date observed","001,obs-a,2020","DUP,obs-b,2020","DUP,obs-c,2020",
 ",obs-d,2020","NA,obs-e,2020"," space,obs-f,2020","unused,obs-g,2020"),file.path(stage,"core.csv"))
writeLines(c("coreid,value","001,1","001,2","DUP,3",",4","missing,5","NA,6","001 ,7"," space,8","1,9"),file.path(stage,"measurements.csv"))
path<-file.path(stage,"synthetic.zip");zip::zipr(path,c("meta.xml","core.csv","measurements.csv"),root=stage)
v<-register_input(path,list(title="Synthetic linkage fixture"),repo)
cfg<-save_configuration(repo,v$version_id,actor_id="acceptance-synthetic")
hash<-get_configuration(repo,cfg$config_id)$context_hash
result<-run_linkage_validation(repo,v$version_id,cfg$config_id)
m<-result$mappings[[1]]
stopifnot(result$status=="completed",length(m$rows)==9L,
 m$summary$counts$linked==4L,m$summary$counts$ambiguous==1L,
 m$summary$counts$missing_reference==1L,m$summary$counts$unresolved_reference==3L,
 m$summary$counts$not_evaluated==0L,length(m$findings)==10L,
 m$multiplicity$core_duplicate_groups==1L,m$multiplicity$core_duplicate_rows==2L,
 m$multiplicity$unique_core_rows_without_measurements==1L,
 identical(get_configuration(repo,cfg$config_id)$context_hash,hash),
 nrow(list_configurations(repo,v$version_id))==1L,nrow(list_operations(repo))==0L)
cat("Synthetic: 7 core rows; 9 measurements -> 9 outcomes: linked4, ambiguous1, missing1, unresolved3.\n")
cat("Duplicate core: 1 group / 2 rows; unmeasured unique core:1; whitespace warnings:3.\n")
dir.create("evidence/linkage",recursive=TRUE,showWarnings=FALSE)
jsonlite::write_json(result,"evidence/linkage/synthetic-result.json",auto_unbox=TRUE,pretty=TRUE,null="null")
examples<-Sys.getenv("ECODATA_EXAMPLES",unset=normalizePath("../../../data_examples",winslash="/"))
obis<-file.path(examples,"OBIS_VeniceLagoon.zip")
source_hash<-hash_file(obis)
real<-register_uploaded_inputs(repo,data.frame(name=basename(obis),size=file.info(obis)$size,type="",datapath=obis),
 "OBIS - key-scope diagnostic, unapproved","acceptance-reader")
cat("Reading real OBIS with the canonical full-table reader; research answers remain pending...\n");flush.console()
input<-read_validation_tables(repo,real$version_id,real$config_id)
core<-Filter(function(t)identical(t$member,"Occurrence.tsv"),input$tables)[[1]]
ext<-Filter(function(t)identical(t$member,"MeasurementOrFact.tsv"),input$tables)[[1]]
position<-function(table,name) {
 p<-which(names(table$data)==name)
 if(length(p)!=1L)stop("Need one unambiguous ",name," header")
 p-1L
}
audit<-compare_linkage_key_scope(input,core$table_id,ext$table_id,
 position(core,"id"),position(ext,"id"),position(core,"dataset_id"),position(ext,"dataset_id"))
blocked<-evaluate_linkage_preparation(input)
stopifnot(audit$resolution=="single_key_sufficient_for_this_snapshot",
 audit$candidate_core_rows==5831L,audit$candidate_extension_rows==2762L,
 audit$core_scope_count==29L,audit$single_key$core_duplicate_groups==0L,
 audit$compound_key$core_duplicate_groups==0L,
 audit$single_key$matching$linked==2762L,audit$compound_key$matching$linked==2762L,
 audit$namespace_disagreements==0L,audit$settings_provisional,!audit$mapping_adopted,
 all(vapply(blocked$mappings,function(m)m$evaluated_measurements==0L,logical(1))),
 nrow(list_configurations(repo,real$version_id))==1L,
 length(clarification_receipts(get_configuration(repo,real$config_id)))==0L,
 verify_input(repo,real$version_id)$ok,identical(source_hash,hash_file(obis)))
jsonlite::write_json(audit,"evidence/linkage/obis-scope-diagnostic.json",auto_unbox=TRUE,pretty=TRUE,null="null")
close_repository(repo);repo<-open_repository(runtime)
stopifnot(identical(get_configuration(repo,cfg$config_id)$context_hash,hash),
 nrow(list_operations(repo))==0L)
close_repository(repo)
jsonlite::write_json(list(runtime=runtime,synthetic=list(
 outcome_counts=m$summary$counts,core_duplicate_groups=1L,core_duplicate_rows=2L,
 unique_core_without_measurement=1L,source_versions_unchanged=TRUE),
 obis=audit,real_approved_answers=0L,operations_created=0L,source_hashes_unchanged=TRUE),
 "evidence/linkage/manual-result.json",auto_unbox=TRUE,pretty=TRUE,null="null")
cat("OBIS:5831 unique ids across29 datasets;2762 unique matches under both id and pair;0 namespace conflicts.\n")
cat("Compound key not needed for this snapshot; no real parser/semantic answers adopted.\n")
cat("Source hashes/configurations unchanged after restart; no history/result writes.\n")
cat("Runtime:",runtime,"\n")
