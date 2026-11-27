#' Retrieve a validation request and its persistent lifecycle/progress
#' @param repo Open repository handle.
#' @param operation_id Exact validation operation ID.
#' @return Immutable request/frozen snapshot, current status, worker claim,
#'   cancellation flag and ordered progress. No source files are read.
#' @export
get_validation_run <- function(repo, operation_id) {
  row <- one_row(repo, "validation_requests", "operation_id", operation_id)
  request <- decode_json(row$request_json); frozen <- decode_json(row$frozen_json)
  if (!identical(hash_text(json_text(request)), row$request_hash) ||
      !identical(hash_text(json_text(frozen)), row$frozen_hash)) stop("Validation request integrity mismatch")
  op <- get_operation(repo, operation_id)
  list(operation_id = operation_id, request = request, frozen = frozen, frozen_hash = row$frozen_hash,
    status = utils::tail(op$events$status, 1), events = op$events,
    claim = DBI::dbGetQuery(repo$con, "SELECT * FROM validation_claims WHERE operation_id = ?", params = list(operation_id)),
    cancel_requested = nrow(DBI::dbGetQuery(repo$con, "SELECT operation_id FROM validation_cancellations WHERE operation_id = ?", params = list(operation_id))) > 0L,
    progress = DBI::dbGetQuery(repo$con, "SELECT * FROM validation_progress WHERE operation_id = ? ORDER BY sequence", params = list(operation_id)))
}

#' List saved validation runs, including removed source versions
#' @param repo Open repository handle.
#' @param version_id Optional exact source version filter; NULL lists all.
#' @return Data frame with exact source/configuration IDs and current status.
#' @export
list_validation_runs <- function(repo, version_id = NULL) {
  sql <- paste("SELECT o.operation_id,o.version_id,o.config_id,o.created_at,o.actor_id,e.status",
    "FROM validation_requests v JOIN operations o ON o.operation_id=v.operation_id",
    "JOIN operation_events e ON e.operation_id=o.operation_id",
    "WHERE e.sequence=(SELECT MAX(x.sequence) FROM operation_events x WHERE x.operation_id=o.operation_id)")
  if (!is.null(version_id)) { scalar_text(version_id, "version_id"); sql <- paste(sql, "AND o.version_id=?") }
  DBI::dbGetQuery(repo$con, paste(sql, "ORDER BY o.rowid DESC"), params = if (is.null(version_id)) NULL else list(version_id))
}

validation_progress_locked <- function(repo, operation_id, family, status, message) {
  sequence <- DBI::dbGetQuery(repo$con, "SELECT COALESCE(MAX(sequence),0)+1 AS n FROM validation_progress WHERE operation_id=?", params=list(operation_id))$n
  DBI::dbExecute(repo$con, "INSERT INTO validation_progress VALUES (?,?,?,?,?,?)",
    params=list(operation_id,sequence,family,status,message,utc_now()))
}

validation_worker_owned <- function(run, token) {
  nrow(run$claim) == 1L && identical(run$claim$worker_token, token) && run$status == "running"
}

# Serialise and build batches before reserving the SQLite writer. Scientific
# scanning and per-row JSON work must not hold a write transaction.
prepare_validation_batches <- function(result) {
  operation_id<-result$operation_id
  batches<-list()
  for (family in names(result$families)) for (i in seq_along(result$families[[family]]$mappings)) {
      m <- result$families[[family]]$mappings[[i]]
      population <- if(family=="dates")m$population_count else m$extension_population
      evaluated <- if(family=="dates")m$evaluated_rows else m$evaluated_measurements
      detail <- m; detail$rows <- NULL; detail$findings <- NULL; detail$checks <- NULL
      if(!is.null(detail$multiplicity))detail$multiplicity$per_unique_key<-NULL
      table_id <- if(!is.null(m$table_id))m$table_id else if(!is.null(m$context))m$context$validation_spec$linkage_mappings[[1]]$extension$table$table_id else NULL
      mapping<-list(operation_id,family,i,
        if(is.null(m$mapping_id))NA_character_ else m$mapping_id,if(is.null(table_id))NA_character_ else table_id,m$status,
        if(is.null(population))NA_integer_ else population,evaluated,json_text(m$summary),json_text(detail))
      rows<-NULL;checks<-list();findings<-list();targets<-list()
      if(length(m$rows)) {
        rows <- data.frame(operation_id=operation_id,family=family,mapping_index=i,
          row_number=vapply(m$rows,function(r)r$row_number,numeric(1)),
          status=vapply(m$rows,function(r)if(family=="dates")r$status else r$outcome,character(1)),
          table_id=vapply(m$rows,function(r)r$table_id,character(1)),
          record_json=vapply(m$rows,json_text,character(1)),stringsAsFactors=FALSE)
      }
      for(j in seq_along(m$checks)) {
        check<-m$checks[[j]]
        checks[[j]]<-list(paste(operation_id,family,i,"check",j,sep=":"),operation_id,family,i,check$rule_id,json_text(check))
      }
      for(j in seq_along(m$findings)) {
        finding<-m$findings[[j]];id<-paste(operation_id,family,i,"finding",j,sep=":")
        findings[[j]]<-list(id,operation_id,family,i,finding$rule_id,finding$severity,json_text(finding))
        if(length(finding$row_locators))targets[[length(targets)+1L]]<-
          data.frame(finding_id=id,row_locator=unlist(finding$row_locators),original_value=unlist(finding$original_values),stringsAsFactors=FALSE)
      }
      batches[[length(batches)+1L]]<-list(mapping=mapping,rows=rows,checks=checks,findings=findings,targets=targets)
    }
  records_frame<-function(records,fields) {
    if(!length(records))return(NULL)
    as.data.frame(stats::setNames(lapply(seq_along(fields),function(j)
      unlist(lapply(records,function(r)r[[j]]),use.names=FALSE)),fields),stringsAsFactors=FALSE)
  }
  flatten<-function(field)unlist(lapply(batches,function(b)b[[field]]),recursive=FALSE)
  row_frames<-Filter(Negate(is.null),lapply(batches,function(b)b$rows))
  target_frames<-flatten("targets")
  tables<-list(
    validation_mappings=records_frame(lapply(batches,function(b)b$mapping),c("operation_id","family","mapping_index","mapping_id","table_id","status","population_count","evaluated_count","summary_json","detail_json")),
    validation_rows=if(length(row_frames))do.call(rbind,row_frames) else NULL,
    validation_checks=records_frame(flatten("checks"),c("check_id","operation_id","family","mapping_index","rule_id","record_json")),
    validation_findings=records_frame(flatten("findings"),c("finding_id","operation_id","family","mapping_index","rule_id","severity","record_json")),
    validation_finding_targets=if(length(target_frames))do.call(rbind,target_frames) else NULL)
  list(payload=json_text(result),tables=tables)
}

# One short transaction owns all normalised scientific output and terminal event.
persist_validation_result <- function(repo, operation_id, token, result) {
  run<-get_validation_run(repo,operation_id)
  bad<-character()
  prepared<-prepare_validation_batches(result)
  repeat {
    # Recheck after all expensive staging, outside the SQLite write reservation.
    if(!identical(validation_code_fingerprint(),run$frozen$code_hash))stop("Application code changed before result commit")
    verified<-verify_input(repo,run$frozen$version_id)$resources
    current_bad<-verified$resource_id[is.na(verified$ok)|!verified$ok]
    new_bad<-setdiff(current_bad,bad)
    if(!length(new_bad)){verified_at<-utc_now();break}
    bad<-union(bad,new_bad)
    for(family in names(result$families))result$families[[family]]<-invalidate_validation_family(result$families[[family]],family,bad)
    result$status<-validation_overall_status(result$families)
    prepared<-prepare_validation_batches(result)
  }
  with_write(repo$con, function() {
    run <- get_validation_run(repo, operation_id)
    if (!validation_worker_owned(run, token)) stop("Validation worker no longer owns this run")
    if (result$operation_id != operation_id || result$config_id != run$frozen$config_id ||
        result$config_hash != run$frozen$config_hash || result$frozen_hash != run$frozen_hash) stop("Result differs from frozen request")
    if (run$cancel_requested && result$status != "cancelled") {
      result$status<-"cancelled"
      result$families<-stats::setNames(lapply(run$request$families,function(x)list(status="cancelled",mappings=list(),reason="Cancelled before atomic commit; partial classifications discarded")),unlist(run$request$families))
      prepared<-prepare_validation_batches(result)
    }
    DBI::dbExecute(repo$con,"INSERT INTO validation_results VALUES (?,?,?)",params=list(operation_id,prepared$payload,hash_text(prepared$payload)))
    for(table in names(prepared$tables))if(!is.null(prepared$tables[[table]]))DBI::dbAppendTable(repo$con,table,prepared$tables[[table]])
    for(family in names(result$families))validation_progress_locked(repo,operation_id,family,result$families[[family]]$status,
      if(identical(result$families[[family]]$status,"failed"))result$families[[family]]$error else "Final saved assessment; see coverage and classifications")
    validation_progress_locked(repo,operation_id,"run",result$status,paste("Source and application snapshot verified after staging at",verified_at))
    record_operation_event_locked(repo,operation_id,result$status,"validation-worker",
      if(result$status=="completed")"Enabled checks finished; findings are not a dataset pass" else "See saved family status and coverage limitations")
  })
  invisible(operation_id)
}

#' Retrieve a saved, hash-verified structured validation result
#' @param repo Open repository handle.
#' @param operation_id Exact validation operation ID.
#' @return Full validation-run-1.0 payload, or NULL before atomic finalisation.
#'   Historical retrieval does not require an active input or unchanged parser.
#' @export
get_validation_result <- function(repo, operation_id) {
  get_validation_run(repo,operation_id)
  row <- DBI::dbGetQuery(repo$con,"SELECT * FROM validation_results WHERE operation_id=?",params=list(operation_id))
  if(!nrow(row))return(NULL)
  if(hash_text(row$payload_json)!=row$result_hash)stop("Saved validation result integrity mismatch")
  decode_json(row$payload_json)
}

#' Query saved validation details with SQL pagination
#' @param repo Open repository handle.
#' @param operation_id Exact validation operation ID.
#' @param kind dates, linkage, findings or checks.
#' @param page One-based page number.
#' @param page_size Positive page size, at most 200.
#' @param status Optional exact row status or finding severity filter.
#' @return List of total, page, page_size and decoded records in stable order.
#' @export
query_validation_details <- function(repo, operation_id, kind, page=1L, page_size=25L, status=NULL) {
  get_validation_run(repo,operation_id)
  kind <- contract_enum(kind,c("dates","linkage","findings","checks"),"detail kind")
  page <- integer_bound(page,"page",.Machine$integer.max); page_size <- integer_bound(page_size,"page_size",200L)
  table <- switch(kind,dates="validation_rows",linkage="validation_rows",findings="validation_findings",checks="validation_checks")
  where <- "operation_id=?"; args <- list(operation_id)
  if(kind%in%c("dates","linkage")){where<-paste(where,"AND family=?");args<-c(args,list(kind))}
  if(!is.null(status)&&nzchar(status)) {
    scalar_text(status,"status")
    if(kind=="checks")stop("Checks do not support a row-status filter")
    where<-paste(where,if(kind=="findings")"AND severity=?" else "AND status=?");args<-c(args,list(status))
  }
  total<-DBI::dbGetQuery(repo$con,paste("SELECT count(*) AS n FROM",table,"WHERE",where),params=args)$n
  order<-if(kind%in%c("dates","linkage"))"mapping_index,row_number" else if(kind=="findings")"mapping_index,rule_id,finding_id" else "mapping_index,rule_id,check_id"
  rows<-DBI::dbGetQuery(repo$con,paste("SELECT record_json FROM",table,"WHERE",where,"ORDER BY",order,"LIMIT ? OFFSET ?"),
    params=c(args,list(page_size,(as.double(page)-1)*page_size)))
  list(total=total,page=page,page_size=page_size,records=lapply(rows$record_json,decode_json))
}

#' Read saved coverage summaries without loading full row details
#' @param repo Open repository handle.
#' @param operation_id Exact validation operation ID.
#' @return Run metadata, per-mapping coverage and aggregated date/linkage counts.
#' @export
get_validation_summary <- function(repo, operation_id) {
  run<-get_validation_run(repo,operation_id)
  rows<-DBI::dbGetQuery(repo$con,"SELECT family,mapping_index,detail_json FROM validation_mappings WHERE operation_id=? ORDER BY family,mapping_index",params=list(operation_id))
  date_counts<-stats::setNames(as.list(rep(0L,6)),c("recognised","ambiguous","unrecognised","missing","incomplete","not_evaluated"))
  linkage_counts<-stats::setNames(as.list(rep(0L,5)),c("linked","ambiguous","missing_reference","unresolved_reference","not_evaluated"))
  mappings<-lapply(seq_len(nrow(rows)),function(i){
    m<-decode_json(rows$detail_json[[i]]); m$family<-rows$family[[i]]
    m
  })
  for(m in mappings) if(!is.null(m$summary)) {
    for(label in names(m$summary$counts))if(m$family=="dates")date_counts[[label]]<-date_counts[[label]]+m$summary$counts[[label]] else
      linkage_counts[[label]]<-linkage_counts[[label]]+m$summary$counts[[label]]
  }
  findings<-DBI::dbGetQuery(repo$con,"SELECT severity,count(*) AS count FROM validation_findings WHERE operation_id=? GROUP BY severity",params=list(operation_id))
  list(run=run,mappings=mappings,date_counts=date_counts,linkage_counts=linkage_counts,findings=findings)
}
