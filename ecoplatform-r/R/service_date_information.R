# Date-format suggestions are technical, not semantic date roles or calendar checks.
infer_date_format <- function(values) {
  # Repetition cannot change an all-values format match. Wide abundance tables
  # contain many repeated zeros/counts; inspect each distinct text once.
  values <- unique(values[!vapply(values,blank_contract_value,logical(1))])
  patterns <- date_patterns("date-patterns-1.2")$patterns
  ids <- names(Filter(function(p)p$kind!="split",patterns))
  candidates <- Filter(function(id)length(values)>0L && all(vapply(values,function(v)
    date_pattern_match(list(value=v),patterns[[id]]),logical(1))),ids)
  # Plausible month positions can distinguish otherwise identical lexical shapes.
  # This is suggestion evidence only; impossible dates are never repaired/converted.
  if (length(candidates)>1L) candidates <- Filter(function(id) {
    p<-patterns[[id]]
    if(!p$kind%in%c("single")||!p$order%in%c("DMY","MDY"))return(TRUE)
    bits<-strsplit(values,p$separator,fixed=TRUE)
    month<-vapply(bits,function(x)as.integer(x[[if(p$order=="DMY")2L else 1L]]),integer(1))
    all(month>=1L & month<=12L)
  },candidates)
  list(selected=if(length(candidates)==1L)candidates[[1]] else NULL,
    candidates=as.list(candidates),examples=as.list(utils::head(unique(values),3L)),
    reason=if(!length(values))"No nonblank values; choose a format." else if(length(candidates)==1L)
      "Inferred from the values. You can change this format." else if(length(candidates)>1L)
      "Ambiguous date order; choose the intended format." else
      "Mixed or unsupported formats; choose the expected format for validation.")
}

prepare_date_information <- function(repo,version_id,config_id,expected_workspace_revision=NULL) {
  request<-prepare_clarifications(repo,version_id,config_id,expected_workspace_revision)
  request$date_fields<-lapply(request$preparation$tables,function(table) {
    if(table$status!="complete"||is.null(table$data))return(list(table_id=table$table_id,fields=list()))
    list(table_id=table$table_id,fields=lapply(seq_along(table$data),function(i)
      c(list(position=i-1L,header=table$schema$headers[[i]]),infer_date_format(table$data[[i]]))))
  })
  request
}

# One explicit Run action confirms all selected fields and exact formats together.
save_date_declarations <- function(repo,request,declarations,actor_id,replace_table_ids=NULL) {
  cfg<-clarification_context(repo,request)
  scalar_text(actor_id,"actor_id")
  if(!is.list(declarations)||!length(declarations))stop("Select at least one date field and its format")
  preparation<-request$preparation
  if(!identical(preparation$config_hash,cfg$context_hash))stop("Date information context mismatch")
  checked<-verify_input(repo,cfg$version_id)$resources
  if(any(is.na(checked$ok)|!checked$ok))stop("Input integrity failed; register a corrected source")
  mappings<-lapply(declarations,function(d) {
    table<-find_prepared_table(preparation,d$table_id)
    if(is.null(table)||table$status!="complete")stop("Select a completely readable date table")
    columns<-d$columns
    if(is.list(columns))columns<-unlist(columns,use.names=TRUE)
    new_date_mapping(table$schema,paste0("declared-date:",table$table_id,":",paste(columns,collapse="-")),
      "date_field",columns,"user",actor_id,"Date field and format selected in Missing information",
      TRUE,declared_pattern=d$pattern_id)
  })
  ids<-vapply(mappings,`[[`,character(1),"mapping_id")
  if(anyDuplicated(ids))stop("A date field cannot be declared twice")
  spec<-cfg$validation_spec
  if(is.null(spec))spec<-new_validation_spec(pattern_version="date-patterns-1.2")
  # Save exact executable definitions even when an older configuration used 0.1.
  spec<-new_validation_spec(spec$date_mappings,spec$linkage_mappings,
    unlist(spec$enabled_rules),enabled_patterns=unique(c(as.character(unlist(spec$enabled_patterns)),
      vapply(declarations,`[[`,character(1),"pattern_id"))),pattern_version="date-patterns-1.2")
  if(is.null(replace_table_ids))replace_table_ids<-unique(vapply(mappings,function(m)m$table$table_id,character(1)))
  known<-vapply(preparation$tables,`[[`,character(1),"table_id")
  if(any(!replace_table_ids%in%known))stop("Unknown date table selection")
  spec$date_mappings<-Filter(function(old)!old$table$table_id%in%replace_table_ids,spec$date_mappings)
  spec$date_mappings<-c(spec$date_mappings,mappings)
  metadata<-cfg$metadata
  metadata$date_format_selection<-list(mapping_ids=as.list(ids))
  save_configuration(repo,cfg$version_id,parsers=cfg$parsers,metadata=metadata,schema=cfg$schema,
    expected_revision=cfg$revision,actor_id=actor_id,validation_spec=spec,
    expected_workspace_revision=request$workspace_revision)
}

start_date_information_worker <- function(repo,context) {
  path<-getNamespaceInfo(asNamespace("ecodata"),"path")
  callr::r_bg(function(path,root,version,config,revision) {
    if(file.exists(file.path(path,"R","service_date_information.R")))pkgload::load_all(path,quiet=TRUE) else library(ecodata)
    r<-ecodata::open_repository(root);on.exit(ecodata::close_repository(r))
    get("prepare_date_information",asNamespace("ecodata"))(r,version,config,revision)
  },args=list(path,repo$root,context$version_id,context$config$config_id,context$workspace_revision),
    libpath=.libPaths(),supervise=TRUE,user_profile=FALSE,system_profile=FALSE,
    env=c(callr::rcmd_safe_env(),LANG="en_US.UTF-8",LC_ALL=if(.Platform$OS.type=="windows")"English_United States.utf8" else "C.UTF-8"))
}
