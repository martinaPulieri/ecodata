# Exact decoded-text index. Factor labels use group numbers, never source values,
# so separators, whitespace and Unicode in identifiers cannot collide.
linkage_index <- function(keys) {
  if(!is.character(keys)||anyNA(keys))stop("Linkage columns must contain decoded non-NA character values")
  missing<-vapply(keys,blank_contract_value,logical(1))
  present<-which(!missing)
  unique_keys<-unique(keys[present])
  group_id<-match(keys[present],unique_keys)
  groups<-if(length(present))unname(split(present,factor(group_id,levels=seq_along(unique_keys)))) else list()
  list(keys=unique_keys,groups=groups,counts=lengths(groups),missing=missing)
}

linkage_counts <- function(index,references) {
  if(!is.character(references)||anyNA(references))stop("References must contain decoded non-NA character values")
  missing<-vapply(references,blank_contract_value,logical(1))
  group<-match(references,index$keys)
  counts<-index$counts[group];counts[is.na(counts)|missing]<-0L
  labels<-ifelse(missing,"missing_reference",ifelse(counts==0L,"unresolved_reference",
    ifelse(counts==1L,"linked","ambiguous")))
  list(missing=missing,group=group,counts=counts,labels=labels)
}

linkage_whitespace <- function(values)!vapply(values,blank_contract_value,logical(1))&
  grepl("^[\\h\\v]|[\\h\\v]$",values,perl=TRUE)

linkage_multiplicity <- function(index,matches,core_table) {
  reference_count<-tabulate(matches$group[!is.na(matches$group)&!matches$missing],nbins=length(index$keys))
  unique_groups<-which(index$counts==1L)
  per_key<-lapply(unique_groups,function(g)list(
    core_row=index$groups[[g]][[1]],row_locator=row_locator(core_table$table_id,index$groups[[g]][[1]]),
    original_key=index$keys[[g]],measurement_count=reference_count[[g]]))
  denominator<-length(unique_groups)
  measured<-sum(reference_count[unique_groups]>0L)
  list(core_missing_rows=sum(index$missing),core_duplicate_groups=sum(index$counts>1L),
    core_duplicate_rows=sum(index$counts[index$counts>1L]),eligible_unique_core_rows=denominator,
    uniquely_linked_core_rows=measured,unique_core_rows_without_measurements=denominator-measured,
    coverage=if(denominator)measured/denominator else NULL,per_unique_key=per_key,
    ambiguous_measurement_rows=sum(matches$labels=="ambiguous"),
    unresolved_measurement_rows=sum(matches$labels=="unresolved_reference"),
    missing_reference_rows=sum(matches$missing))
}

# Contexts are scoped per mapping. A stale schema in another mapping/date field
# cannot invalidate an otherwise usable relationship. No saved config is edited.
linkage_execution_context <- function(input,mapping) {
  spec<-input$configuration$validation_spec
  if(is.null(spec))spec<-new_validation_spec()
  spec$date_mappings<-list();spec$linkage_mappings<-list(mapping)
  resources<-Filter(function(r)identical(r$resource_id,mapping$core$table$resource_id),input$resources)
  context<-list(contract_version="validation-contracts-1.0",version_id=input$version_id,
    config_id=input$config_id,config_hash=input$config_hash,workspace_revision=input$workspace_revision,
    resources=lapply(resources,function(r)r[c("resource_id","sha256","original_name","size_bytes")]),
    validation_spec=spec)
  context$context_hash<-hash_text(json_text(context))
  validate_frozen_context(context)
  contract_copy(context)
}

linkage_population <- function(table)if(is.null(table))NULL else table$population_count

linkage_blocked <- function(input,prerequisite,status,reason,limits,context=NULL,cancelled=NULL) {
  mapping<-prerequisite$mapping
  core<-if(is.null(mapping))NULL else find_prepared_table(input,mapping$core$table$table_id)
  ext<-if(is.null(mapping))find_prepared_table(input,prerequisite$table_id) else find_prepared_table(input,mapping$extension$table$table_id)
  source_id<-if(is.null(mapping))prerequisite$resource_id else mapping$core$table$resource_id
  if(is.null(mapping)&&!is.null(ext)&&(is.null(ext$declaration)||!identical(ext$declaration$kind,"extension")))ext<-NULL
  population<-linkage_population(ext)
  rows<-list();summary<-NULL
  # Known readable references can carry explicit not_evaluated rows. Unknown
  # headers/populations or output quotas never manufacture an empty population.
  enabled<-if(is.null(context))character() else unlist(context$validation_spec$enabled_rules)
  usable<-!is.null(mapping)&&!is.null(ext)&&!is.null(population)&&
    identical(ext$status,"complete")&&contract_equal(ext$schema,mapping$extension$table)&&
    population<=limits$max_output_rows&&"LNK-01"%in%enabled&&!status%in%c("cancelled","unreadable")
  payload<-tryCatch({
    if(!status%in%c("cancelled","unreadable"))poll_linkage_cancellation(cancelled)
    if(usable) {
      references<-ext$data[[mapping$extension$column$position+1L]]
      rows<-lapply(seq_along(references),function(i) {
        poll_linkage_cancellation(cancelled)
        new_linkage_result(context,mapping$mapping_id,i,references[[i]],"not_evaluated",reason=reason)
      })
      summary<-summarise_linkage_results(context,mapping$mapping_id,rows,population,cancelled=cancelled)
      poll_linkage_cancellation(cancelled)
    }
    list(status=status,reason=reason,rows=rows,summary=summary)
  },ecodata_read_cancelled=function(e)list(status="cancelled",reason=conditionMessage(e),rows=list(),summary=NULL))
  status<-payload$status;reason<-payload$reason;rows<-payload$rows;summary<-payload$summary
  list(mapping_id=if(is.null(mapping))NULL else mapping$mapping_id,
    resource_id=source_id,
    status=status,reason=reason,context=context,
    core_population=linkage_population(core),extension_population=population,
    evaluated_measurements=0L,unclassified_rows=if(is.null(population))NULL else population-length(rows),
    rows=rows,summary=summary,findings=list(),checks=list(),multiplicity=NULL,
    disabled_rules=as.list(setdiff(paste0("LNK-0",2:8),enabled)))
}

evaluate_linkage_mapping <- function(input,prerequisite,limits,cancelled) {
  mapping<-prerequisite$mapping
  context<-if(is.null(mapping))NULL else linkage_execution_context(input,mapping)
  blocked<-function(status,reason)linkage_blocked(input,prerequisite,status,reason,limits,context,cancelled)
  if(cancelled())return(blocked("cancelled","Linkage cancelled before evaluation; no partial results retained"))
  if(prerequisite$status!="ready"||is.null(mapping))
    return(blocked(if(prerequisite$status=="not_applicable")"not_applicable" else "not_evaluated",prerequisite$reason))
  enabled<-unlist(context$validation_spec$enabled_rules)
  absent<-setdiff(paste0("LNK-0",1:6),enabled)
  if(length(absent))return(blocked("not_evaluated",paste("Disabled mandatory linkage rules:",paste(absent,collapse=", "))))
  core<-find_prepared_table(input,mapping$core$table$table_id)
  ext<-find_prepared_table(input,mapping$extension$table$table_id)
  nc<-nrow(core$data);ne<-nrow(ext$data)
  if(nc+ne>limits$max_output_rows)return(blocked("limited","Combined source/output row quota exceeded"))
  keys<-core$data[[mapping$core$column$position+1L]]
  references<-ext$data[[mapping$extension$column$position+1L]]
  index<-linkage_index(keys);matches<-linkage_counts(index,references)
  if(sum(matches$counts)>limits$max_candidate_targets)
    return(blocked("limited","Candidate target quota exceeded; no partial linkage results retained"))
  whitespace_core<-linkage_whitespace(keys);whitespace_ext<-linkage_whitespace(references)
  finding_count<-sum(index$missing)+sum(index$counts>1L)+
    sum(matches$labels%in%c("missing_reference","unresolved_reference","ambiguous"))+
    if("LNK-08"%in%enabled)sum(whitespace_core)+sum(whitespace_ext) else 0L
  if(finding_count>limits$max_findings)return(blocked("limited","Finding quota exceeded; no partial results retained"))
  tryCatch({
    tick<-function(i=0L)if(i%%128L==0L&&cancelled())read_stop("cancelled","Linkage cancelled; partial results discarded")
    tick()
    rows<-lapply(seq_along(references),function(i){
      tick(i)
      targets<-if(matches$counts[[i]])as.numeric(index$groups[[matches$group[[i]]]]) else numeric()
      new_linkage_result(context,mapping$mapping_id,i,references[[i]],matches$labels[[i]],targets)
    })
    findings<-list()
    add<-function(rule,table,row,values,reason) {
      tick(length(findings))
      findings[[length(findings)+1L]]<<-new_validation_finding(context,rule,table$table_id,
        as.numeric(row),values,reason,mapping_id=mapping$mapping_id)
    }
    for(i in which(index$missing))add("LNK-02",core,i,keys[i],"Core identifier is empty or whitespace only")
    for(g in which(index$counts>1L))add("LNK-03",core,index$groups[[g]],keys[index$groups[[g]]],
      "Exact repeated core-key group; uniqueness of the declared relationship is violated")
    for(i in which(matches$labels=="missing_reference"))add("LNK-04",ext,i,references[i],"Measurement reference is empty or whitespace only")
    for(i in which(matches$labels=="unresolved_reference"))add("LNK-05",ext,i,references[i],"No exact nonmissing target in the declared core table")
    for(i in which(matches$labels=="ambiguous"))add("LNK-06",ext,i,references[i],"Multiple exact core targets; candidates retained in the row outcome")
    if("LNK-08"%in%enabled) {
      for(i in which(whitespace_core))add("LNK-08",core,i,keys[i],linkage_whitespace_evidence(keys[i]))
      for(i in which(whitespace_ext))add("LNK-08",ext,i,references[i],linkage_whitespace_evidence(references[i]))
    }
    checks<-lapply(intersect(paste0("LNK-0",2:8),enabled),function(rule){
      core_rule<-rule%in%c("LNK-02","LNK-03","LNK-07")
      population<-if(rule=="LNK-08")nc+ne else if(core_rule)nc else ne
      tables<-if(rule=="LNK-08")c(core$table_id,ext$table_id) else if(core_rule)core$table_id else ext$table_id
      new_check_result(context,rule,tables,"applicable","completed",population,population)
    })
    summary<-summarise_linkage_results(context,mapping$mapping_id,rows,ne,cancelled=cancelled)
    tick()
    list(mapping_id=mapping$mapping_id,resource_id=mapping$core$table$resource_id,
      status="completed",reason="Complete exact-text linkage; no source rows joined or changed",
      context=context,core_population=nc,extension_population=ne,evaluated_measurements=ne,
      unclassified_rows=0L,rows=rows,summary=summary,findings=findings,checks=checks,
      multiplicity=if("LNK-07"%in%enabled)linkage_multiplicity(index,matches,core$schema) else NULL,
      disabled_rules=as.list(setdiff(paste0("LNK-0",2:8),enabled)))
  },ecodata_read_cancelled=function(e)blocked("cancelled",conditionMessage(e)))
}


poll_linkage_cancellation <- function(cancelled) {
  if(is.null(cancelled))return(invisible(FALSE))
  if(!is.function(cancelled))stop("cancelled must be a function")
  flag<-cancelled()
  if(!is.logical(flag)||length(flag)!=1L||is.na(flag))stop("Invalid cancellation flag")
  if(flag)read_stop("cancelled","Linkage cancelled while constructing or reconciling outputs; partial records discarded")
  invisible(FALSE)
}

linkage_whitespace_evidence <- function(value) {
  leading<-regmatches(value,regexpr(r"(^[\h\v]+)",value,perl=TRUE))
  trailing<-regmatches(value,regexpr(r"([\h\v]+$)",value,perl=TRUE))
  codes<-function(x)if(!length(x)||!nzchar(x))"none" else
    paste(sprintf("U+%04X",utf8ToInt(x)),collapse=" ")
  paste("Significant edge whitespace; leading:",codes(leading),"; trailing:",codes(trailing),
    "; original:",encodeString(value,quote=intToUtf8(34)))
}
