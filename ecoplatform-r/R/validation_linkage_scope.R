# Collision-free tuple spelling: byte lengths frame each UTF-8 component.
# Separators inside values cannot create false matches; nothing is trimmed.
linkage_tuple <- function(scope,key) {
  if(length(scope)!=length(key))stop("Tuple component lengths differ")
  if(!length(key))return(character())
  scope<-enc2utf8(scope);key<-enc2utf8(key)
  paste0(nchar(scope,type="bytes"),":",scope,nchar(key,type="bytes"),":",key)
}

scope_key_summary <- function(index,matches) {
  labels<-c("linked","ambiguous","missing_reference","unresolved_reference")
  list(core_missing_rows=sum(index$missing),core_unique_nonmissing_keys=length(index$keys),
    core_duplicate_groups=sum(index$counts>1L),core_duplicate_rows=sum(index$counts[index$counts>1L]),
    matching=stats::setNames(lapply(labels,function(label)sum(matches$labels==label)),labels))
}

#' Compare a candidate identifier with its namespace-qualified counterpart
#'
#' Read-only diagnostic, not adoption of a mapping. Exact identifier and scope
#' components remain unchanged. Missing components, namespace conflicts and
#' still-duplicate compound keys are reported explicitly. This function does
#' not approve parser settings or extend the single-column linkage contract.
#' @param input Fresh preparation from read_validation_tables(). This pure
#'   diagnostic does not reopen files; provenance refers to that input snapshot.
#' @param core_table_id,extension_table_id Exact distinct tables in one archive.
#' @param core_id_position,extension_reference_position Zero-based candidate ID positions.
#' @param core_scope_position,extension_scope_position Zero-based namespace positions.
#' @return linkage-key-scope-1.0 with candidate populations, exact positional
#'   evidence, duplicate/matching counts, missing/conflict diagnostics and a
#'   scoped resolution. settings_provisional discloses unapproved technical
#'   settings; mapping_adopted is always FALSE.
#' @export
compare_linkage_key_scope <- function(input,core_table_id,extension_table_id,
  core_id_position,extension_reference_position,core_scope_position,extension_scope_position) {
  if(!identical(input$contract_version,"validation-preparation-1.0"))stop("Unsupported validation preparation")
  core<-find_prepared_table(input,core_table_id);ext<-find_prepared_table(input,extension_table_id)
  if(is.null(core)||is.null(ext)||identical(core_table_id,extension_table_id))
    stop("Select two actual distinct tables")
  if(core$resource_id!=ext$resource_id||is.null(core$member)||is.null(ext$member))
    stop("Candidate table scope must remain inside one archive")
  resource<-Filter(function(r)identical(r$resource_id,core$resource_id),input$resources)
  if(length(resource)!=1L||!isTRUE(resource[[1]]$integrity_ok))stop("Source integrity is not verified")
  for(t in list(core,ext)) {
    if(t$status!="complete"||is.null(t$data)||is.null(t$schema))stop("Candidate table must be completely readable")
    if(!identical(names(t$data),unlist(t$schema$headers,use.names=FALSE)))stop("Actual table headers disagree with schema")
  }
  columns<-list(core_key=column_contract(core$schema,core_id_position),
    core_scope=column_contract(core$schema,core_scope_position),
    extension_reference=column_contract(ext$schema,extension_reference_position),
    extension_scope=column_contract(ext$schema,extension_scope_position))
  if(core_id_position==core_scope_position||extension_reference_position==extension_scope_position)
    stop("Scope and identifier columns must be distinct")
  keys<-core$data[[core_id_position+1L]];refs<-ext$data[[extension_reference_position+1L]]
  core_scope<-core$data[[core_scope_position+1L]];ext_scope<-ext$data[[extension_scope_position+1L]]
  if(!all(vapply(list(keys,refs,core_scope,ext_scope),function(v)is.character(v)&&!anyNA(v),logical(1))))
    stop("Candidate columns require exact decoded non-NA text")
  index<-linkage_index(keys);matches<-linkage_counts(index,refs)
  missing_core_scope<-vapply(core_scope,blank_contract_value,logical(1))
  missing_ext_scope<-vapply(ext_scope,blank_contract_value,logical(1))
  core_pair<-linkage_tuple(core_scope,keys);ext_pair<-linkage_tuple(ext_scope,refs)
  core_pair[index$missing|missing_core_scope]<-""
  ext_pair[matches$missing|missing_ext_scope]<-""
  pair_index<-linkage_index(core_pair);pair_matches<-linkage_counts(pair_index,ext_pair)
  unique_refs<-which(matches$counts>0L&!matches$missing)
  disagreements<-0L
  for(i in unique_refs) {
    targets<-index$groups[[matches$group[[i]]]]
    if(!missing_ext_scope[[i]]&&!any(missing_core_scope[targets])&&
      !any(core_scope[targets]==ext_scope[[i]]))disagreements<-disagreements+1L
  }
  cross_namespace<-sum(vapply(index$groups,function(rows)
    length(unique(core_scope[rows][!missing_core_scope[rows]]))>1L,logical(1)))
  incomplete<-!length(keys)||!length(refs)||any(index$missing)||any(matches$missing)||any(missing_core_scope)||any(missing_ext_scope)
  resolution<-if(incomplete)"insufficient_information" else
    if(any(pair_index$counts>1L))"compound_key_insufficient" else
      if(disagreements)"namespace_conflict" else
        if(cross_namespace)"compound_key_required_for_uniqueness" else "single_key_sufficient_for_this_snapshot"
  result<-list(contract_version="linkage-key-scope-1.0",version_id=input$version_id,
    config_id=input$config_id,config_hash=input$config_hash,resource_id=core$resource_id,
    source_sha256=resource[[1]]$sha256,core_table_id=core_table_id,extension_table_id=extension_table_id,
    columns=columns,candidate_core_rows=nrow(core$data),candidate_extension_rows=nrow(ext$data),
    settings_provisional=isTRUE(core$settings_pending)||isTRUE(ext$settings_pending),
    mapping_adopted=FALSE,resolution=resolution,core_scope_count=length(unique(core_scope[!missing_core_scope])),
    single_key=scope_key_summary(index,matches),compound_key=scope_key_summary(pair_index,pair_matches),
    cross_namespace_id_groups=cross_namespace,namespace_disagreements=disagreements,
    missing_core_scope=sum(missing_core_scope),missing_extension_scope=sum(missing_ext_scope))
  result$result_hash<-hash_text(json_text(result))
  contract_copy(result)
}
