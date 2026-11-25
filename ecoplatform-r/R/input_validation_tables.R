# Full-table preparation is read-only and independent from bounded UI previews.
read_stop <- function(status, message) stop(structure(list(message=message,call=NULL),
  class=c(paste0("ecodata_read_",status),"error","condition")))

empty_validation_table <- function(version_id, resource_id, member=NULL, status="unreadable", reason="", declaration=NULL) {
  list(version_id=version_id,resource_id=resource_id,
    table_id=paste0(resource_id,":",if(is.null(member))"table" else member),member=member,
    status=status,reason=reason,population_count=NULL,loaded_rows=0L,data=NULL,
    schema=NULL,record_ids=character(),header_present=NULL,declaration=declaration)
}

read_full_table <- function(bytes, version_id, resource_id, member, parser, limits, cancelled,
  header=TRUE, record_separator=NULL, declaration=NULL) {
  result <- empty_validation_table(version_id,resource_id,member,declaration=declaration)
  tryCatch({
    if(cancelled()) read_stop("cancelled","Reading cancelled before table scan")
    if(length(bytes)>limits$max_table_bytes) read_stop("limited","Table exceeds full-read byte quota")
    parsed <- parse_preview(bytes,parser,limits$max_rows,resource_id,
      if(is.null(member))"table" else member,header,record_separator,limits$max_cells,cancelled)
    if(cancelled()) read_stop("cancelled","Reading cancelled after lexical scan")
    result$status <- if(parsed$truncated)"limited" else "complete"
    result$reason <- if(parsed$truncated)"Data-row quota reached; remaining population not assessed" else "Complete lexical table; no linkage/date quality checks executed"
    result$population_count <- if(parsed$truncated)NULL else nrow(parsed$preview)
    result$loaded_rows <- nrow(parsed$preview);result$data <- parsed$preview
    result$schema <- new_validation_table(version_id,resource_id,parsed$columns,member)
    result$record_ids <- parsed$record_ids;result$header_present <- header
    result$parser <- parser;result$record_separator <- record_separator
    result
  },error=function(e){
    result$status <- if(inherits(e,"ecodata_read_limited"))"limited" else if(inherits(e,"ecodata_read_cancelled"))"cancelled" else "unreadable"
    result$reason <- conditionMessage(e);result
  })
}

#' Read complete registered tables for validation prerequisites
#'
#' Uses the exact saved parser/configuration; preserves decoded text, duplicate
#' headers and logical data-row identities. Quotas and cancellation are explicit.
#' No result operations, mappings, findings or database rows are created.
#' @param repo Open repository handle.
#' @param version_id Exact active source version.
#' @param config_id Exact configuration revision belonging to version_id.
#' @param max_table_bytes Maximum bytes read per table (default 50 MiB).
#' @param max_rows Maximum returned data rows per table (default 1000000).
#' @param max_cells Maximum decoded fields including header (default 5000000).
#' @param cancelled Cooperative function returning one logical flag. Checked at
#'   table boundaries and periodically during lexical scanning.
#' @param expected_workspace_revision Optional displayed lifecycle revision.
#' @return Preparation containing independent table outcomes, configuration,
#'   descriptor declarations, quotas and original resource hashes. Only complete
#'   tables have a known population_count; limited/cancelled/unreadable are not passes.
#' @export
read_validation_tables <- function(repo,version_id,config_id,max_table_bytes=50*1024^2,
  max_rows=1000000L,max_cells=5000000L,cancelled=function()FALSE,expected_workspace_revision=NULL) {
  config <- get_configuration(repo,config_id)
  if(config$version_id!=version_id)stop("Configuration belongs to a different version")
  revision <- assert_workspace_active(repo,version_id,expected_workspace_revision)
  limits <- list(max_table_bytes=integer_bound(max_table_bytes,"max_table_bytes",200*1024^2),
    max_rows=integer_bound(max_rows,"max_rows",.Machine$integer.max-2L),
    max_cells=integer_bound(max_cells,"max_cells",.Machine$integer.max))
  if(!is.function(cancelled))stop("cancelled must be a function")
  cancel <- function(){flag<-cancelled();if(!is.logical(flag)||length(flag)!=1L||is.na(flag))stop("Invalid cancellation flag");flag}
  verified <- verify_input(repo,version_id);resources<-verified$resources
  if(!is.null(config$validation_spec))validate_validation_spec(config$validation_spec,version_id,resources$resource_id)
  tables<-list();resource_outcomes<-list()
  for(i in seq_len(nrow(resources))) {
    resource<-resources[i,,drop=FALSE];rid<-resource$resource_id
    result<-tryCatch({
      if(!resource$ok)stop("Input resource integrity verification failed")
      ext<-tolower(tools::file_ext(resource$original_name))
      if(ext%in%c("csv","tsv")) {
        if(cancel())read_stop("cancelled","Reading cancelled before resource")
        if(resource$size_bytes>limits$max_table_bytes)read_stop("limited","Table exceeds full-read byte quota")
        bytes<-readBin(resource$owned_path,"raw",n=limits$max_table_bytes+1)
        list(tables=list(read_full_table(bytes,version_id,rid,NULL,config$parsers[[rid]],limits,cancel)),reason="Standalone delimited table")
      } else if(ext=="zip") read_validation_archive(resource$owned_path,version_id,rid,limits,cancel,config)
      else list(tables=list(empty_validation_table(version_id,rid,status="unsupported",reason="Unsupported input format")),reason="Unsupported input format")
    },error=function(e)list(tables=list(empty_validation_table(version_id,rid,
      status=if(inherits(e,"ecodata_read_limited"))"limited" else if(inherits(e,"ecodata_read_cancelled"))"cancelled" else "unreadable",
      reason=conditionMessage(e))),reason=conditionMessage(e)))
    tables<-c(tables,unname(result$tables))
    resource_outcomes[[length(resource_outcomes)+1L]]<-list(resource_id=rid,sha256=resource$sha256,original_name=resource$original_name,integrity_ok=isTRUE(resource$ok),reason=result$reason,ignored_members=result$ignored_members)
  }
  # A concurrent external modification invalidates only that resource's views.
  after<-verify_input(repo,version_id)$resources
  for(i in seq_along(tables)) {
    current<-after[after$resource_id==tables[[i]]$resource_id,,drop=FALSE]
    if(!nrow(current)||!current$ok)tables[[i]]<-empty_validation_table(version_id,tables[[i]]$resource_id,
      tables[[i]]$member,reason="Input integrity failed during full reading",declaration=tables[[i]]$declaration)
  }
  for(i in seq_along(resource_outcomes)) {
    current<-after[after$resource_id==resource_outcomes[[i]]$resource_id,,drop=FALSE]
    resource_outcomes[[i]]$integrity_ok<-resource_outcomes[[i]]$integrity_ok&&nrow(current)==1L&&isTRUE(current$ok)
  }
  assert_workspace_active(repo,version_id,revision)
  list(contract_version="validation-preparation-1.0",version_id=version_id,config_id=config_id,
    config_hash=config$context_hash,workspace_revision=revision,configuration=config,
    tables=unname(tables),resources=resource_outcomes,limits=limits,scientific_checks_executed=FALSE)
}
