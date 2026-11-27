#' Submit an exact, persistent validation request
#' @param repo Open repository handle.
#' @param version_id,config_id Exact source version and saved configuration.
#' @param actor_id Explicit operator label.
#' @param request_id Caller-owned idempotency key.
#' @param expected_workspace_revision Optional displayed lifecycle revision.
#' @param families Character vector containing linkage and/or dates.
#' @param max_output_rows Per-family output-row budget, at most one million.
#' @return operation_id/status. Queuing does not execute full-table processing.
#'   Identical keys return their original run, including after source removal;
#'   changed payloads or stale/removed new submissions are rejected.
#' @export
submit_validation_run <- function(repo,version_id,config_id,actor_id,request_id,
  expected_workspace_revision=NULL,families=c("linkage","dates"),max_output_rows=25000L) {
  contract_texts(families,"families")
  if(anyDuplicated(families)||any(!families%in%c("linkage","dates")))stop("Unsupported validation families")
  limits<-list(max_output_rows=integer_bound(max_output_rows,"max_output_rows",1000000L))
  scalar_text(actor_id,"actor_id");scalar_text(request_id,"request_id")
  request<-contract_copy(list(version_id=version_id,config_id=config_id,actor_id=actor_id,
    expected_workspace_revision=expected_workspace_revision,families=as.list(families),limits=limits))
  fingerprint<-hash_text(json_text(request))
  with_write(repo$con,function(){
    old<-DBI::dbGetQuery(repo$con,"SELECT o.operation_id,v.request_hash FROM operations o LEFT JOIN validation_requests v ON v.operation_id=o.operation_id WHERE o.request_id=?",params=list(request_id))
    if(nrow(old)) {
      if(is.na(old$request_hash)||old$request_hash!=fingerprint)stop("request_id was already used for a different validation request")
      run<-get_validation_run(repo,old$operation_id)
      return(list(operation_id=old$operation_id,status=run$status))
    }
    op<-submit_operation_locked(repo,version_id,config_id,"validation",request_id,actor_id,expected_workspace_revision,verify_bytes=FALSE)
    cfg<-get_configuration(repo,config_id); manifest<-get_input(repo,version_id)
    frozen<-contract_copy(list(version_id=version_id,config_id=config_id,config_hash=cfg$context_hash,
      configuration=cfg,code_hash=validation_code_fingerprint(),workspace_revision=get_workspace_state(repo,version_id)$revision,
      resources=lapply(seq_len(nrow(manifest$resources)),function(i)as.list(manifest$resources[i,
        c("resource_id","sha256","original_name","size_bytes"),drop=FALSE]))))
    DBI::dbExecute(repo$con,"INSERT INTO validation_requests VALUES (?,?,?,?,?)",
      params=list(op$operation_id,json_text(request),fingerprint,json_text(frozen),hash_text(json_text(frozen))))
    for(family in families)validation_progress_locked(repo,op$operation_id,family,"queued","Waiting for background worker")
    op
  })
}

# Freeze executable package bytes as well as rule/configuration versions. This
# works for source development checkouts and installed lazy-load R databases.
validation_code_fingerprint <- function() {
  root<-getNamespaceInfo(asNamespace("ecodata"),"path")
  files<-sort(c(list.files(file.path(root,"R"),full.names=TRUE),
    list.files(system.file("rules",package="ecodata",mustWork=TRUE),full.names=TRUE)),method="radix")
  files<-files[!dir.exists(files)]
  hash_text(json_text(lapply(files,function(path)list(name=paste(basename(dirname(path)),basename(path),sep="/"),sha256=hash_file(path)))))
}

#' Request cancellation without falsely completing an active worker
#' @param repo Open repository handle.
#' @param operation_id Exact validation operation ID.
#' @param actor_id Operator label retained in the cancellation receipt.
#' @return Current run metadata, invisibly. Queued runs cancel immediately;
#'   running workers observe the persistent request cooperatively.
#' @export
cancel_validation_run <- function(repo,operation_id,actor_id) {
  scalar_text(actor_id,"actor_id")
  with_write(repo$con,function(){
    legacy<-DBI::dbGetQuery(repo$con,"SELECT o.operation_id FROM operations o LEFT JOIN validation_requests v ON v.operation_id=o.operation_id WHERE o.operation_id=? AND o.operation_type='validation' AND v.operation_id IS NULL",params=list(operation_id))
    if(nrow(legacy)) {
      old<-get_operation(repo,operation_id)
      if(utils::tail(old$events$status,1)%in%c("queued","running"))record_operation_event_locked(repo,operation_id,"cancelled",actor_id,
        "Pre-v3 intent has no frozen validation request; cancelled explicitly. Submit a new run.")
      return(invisible(list(legacy=TRUE,status="cancelled",operation_id=operation_id)))
    }
    run<-get_validation_run(repo,operation_id)
    if(!run$status%in%c("queued","running"))return(invisible(run))
    DBI::dbExecute(repo$con,"INSERT OR IGNORE INTO validation_cancellations VALUES (?,?,?,?)",
      params=list(operation_id,actor_id,"Operator requested cancellation",utc_now()))
    if(run$status=="queued") {
      for(family in unlist(run$request$families))validation_progress_locked(repo,operation_id,family,"cancelled","Cancelled before worker claim; no results saved")
      record_operation_event_locked(repo,operation_id,"cancelled",actor_id,"Cancelled before worker claim")
    }
    invisible(run)
  })
  managed<-DBI::dbGetQuery(repo$con,"SELECT operation_id FROM validation_requests WHERE operation_id=?",params=list(operation_id))
  invisible(if(nrow(managed))get_validation_run(repo,operation_id) else list(operation_id=operation_id,status=utils::tail(get_operation(repo,operation_id)$events$status,1),legacy=TRUE))
}

validation_claim_alive <- function(claim) {
  if(nrow(claim)!=1L)return(FALSE)
  # ps expects a POSIXt birth time, not the numeric SQLite representation.
  # An inability to inspect a process is not evidence that it has stopped.
  tryCatch(ps::ps_is_running(ps::ps_handle(as.integer(claim$pid),
    time=as.POSIXct(as.numeric(claim$process_started),origin="1970-01-01",tz="UTC"))),error=function(e)TRUE)
}

#' Recover an evidenced stopped validation worker
#' @param repo Open repository handle.
#' @param operation_id Exact validation operation ID.
#' @param actor_id Operator label recording the recovery.
#' @return Run metadata. Active PID/birth-time matches cannot be interrupted.
#'   Queued work without a claim must be explicitly cancelled instead.
#' @export
recover_validation_run <- function(repo,operation_id,actor_id) {
  scalar_text(actor_id,"actor_id")
  with_write(repo$con,function(){
    run<-get_validation_run(repo,operation_id)
    if(!run$status%in%c("queued","running"))return(invisible(run))
    if(!nrow(run$claim))stop("Unclaimed queued work can be cancelled")
    if(validation_claim_alive(run$claim))stop("Validation worker is still active")
    for(family in unlist(run$request$families))validation_progress_locked(repo,operation_id,family,"interrupted","Stopped worker; no partial scientific output accepted")
    record_operation_event_locked(repo,operation_id,"interrupted",actor_id,"Worker PID/birth-time no longer exists; no partial result accepted")
  })
  get_validation_run(repo,operation_id)
}

claim_validation_run <- function(repo,operation_id,token) {
  scalar_text(token,"worker token")
  with_write(repo$con,function(){
    run<-get_validation_run(repo,operation_id)
    if(run$status!="queued"||nrow(run$claim))return(FALSE)
    assert_workspace_active(repo,run$frozen$version_id,run$frozen$workspace_revision)
    DBI::dbExecute(repo$con,"INSERT INTO validation_claims VALUES (?,?,?,?,?)",params=list(operation_id,token,
      Sys.getpid(),ps::ps_create_time(ps::ps_handle()),utc_now()))
    record_operation_event_locked(repo,operation_id,"running","validation-worker","Background worker claimed frozen request")
    TRUE
  })
}

validation_progress <- function(repo,operation_id,token,family,status,message) with_write(repo$con,function(){
  run<-get_validation_run(repo,operation_id)
  if(!validation_worker_owned(run,token))stop("Validation worker ownership changed")
  validation_progress_locked(repo,operation_id,family,status,message)
})

invalidate_validation_family <- function(result,family,bad) {
  for(i in seq_along(result$mappings))if(any(result$mappings[[i]]$resource_id%in%bad)) {
    m<-result$mappings[[i]]; m$status<-"unreadable";m$reason<-"Source integrity changed before result commit"
    m$rows<-list();m$findings<-list();m$checks<-list();m$summary<-NULL
    if(family=="dates"){m$population_count<-NULL;m$evaluated_rows<-0L;m$not_evaluated_rows<-NULL;m$pattern_counts<-list()} else {
      m$core_population<-NULL;m$extension_population<-NULL;m$evaluated_measurements<-0L;m$multiplicity<-NULL
    }
    m$unclassified_rows<-NULL;result$mappings[[i]]<-m
  }
  if(!is.null(result$contract_version)) {
    for(field in c("prerequisites","date_prerequisites","linkage_prerequisites"))if(!is.null(result[[field]]))
      result[[field]]<-lapply(result[[field]],function(p){if(any(p$resource_id%in%bad)){
        p$status<-"not_evaluated";p$reason<-"Source integrity changed before result commit";p$eligible_rows<-0L;p$population_count<-NULL};p})
    result<-if(family=="dates")finish_date_evaluation(result) else finish_linkage_evaluation(result)
  }
  result
}

validation_overall_status <- function(families) {
  states<-vapply(families,function(x)x$status,character(1))
  if(any(states=="cancelled"))"cancelled" else if(length(states)&&all(states=="failed"))"failed" else
    if(length(states)&&all(states%in%c("completed","not_applicable")))"completed" else "completed_with_limitations"
}

#' Execute one queued validation request in a worker-owned connection
#' @param runtime_root Local repository runtime path, never a live DBI connection.
#' @param operation_id Exact queued validation operation ID.
#' @param worker_token Explicit worker ownership token.
#' @return Small operation/status list. Atomic finalisation preserves typed rows,
#'   findings, targets and checks. Technical errors are recorded separately from
#'   scientific findings; sibling families continue. Cancellation accepts no
#'   partial scientific output. This entry point is also usable in manual checks.
#' @export
execute_validation_run <- function(runtime_root,operation_id,worker_token) {
  repo<-open_repository(runtime_root);on.exit(close_repository(repo))
  if(!claim_validation_run(repo,operation_id,worker_token))return(list(operation_id=operation_id,status=get_validation_run(repo,operation_id)$status))
  tryCatch({
    run<-get_validation_run(repo,operation_id);f<-run$frozen
    if(!identical(validation_code_fingerprint(),f$code_hash))stop("Application code differs from the frozen request; submit a new run")
    if(get_configuration(repo,f$config_id)$context_hash!=f$config_hash)stop("Frozen configuration integrity mismatch")
    cancelled<-function()get_validation_run(repo,operation_id)$cancel_requested
    families<-list()
    for(family in unlist(run$request$families)) {
      if(cancelled())break
      validation_progress(repo,operation_id,worker_token,family,"running","Reading full configured tables and evaluating enabled checks")
      families[[family]]<-tryCatch({
        fn<-if(family=="dates")run_date_validation else run_linkage_validation
        fn(repo,f$version_id,f$config_id,cancelled=cancelled,max_output_rows=run$request$limits$max_output_rows,
          expected_workspace_revision=f$workspace_revision)
      },error=function(e)list(status="failed",error=conditionMessage(e),mappings=list()))
      validation_progress(repo,operation_id,worker_token,family,families[[family]]$status,
        if(families[[family]]$status=="failed")families[[family]]$error else "Family finished; see coverage and saved classifications")
    }
    if(cancelled()||any(vapply(families,function(x)x$status=="cancelled",logical(1)))) {
      families<-stats::setNames(lapply(run$request$families,function(x)list(status="cancelled",mappings=list(),reason="Cancelled; partial classifications discarded")),unlist(run$request$families))
      status<-"cancelled"
    } else {
      verified<-verify_input(repo,f$version_id)$resources
      bad<-verified$resource_id[is.na(verified$ok)|!verified$ok]
      for(family in names(families))families[[family]]<-invalidate_validation_family(families[[family]],family,bad)
      status<-validation_overall_status(families)
    }
    result<-contract_copy(list(contract_version="validation-run-1.0",operation_id=operation_id,
      version_id=f$version_id,config_id=f$config_id,config_hash=f$config_hash,frozen_hash=run$frozen_hash,
      status=status,calendar_validation=FALSE,families=families))
    persist_validation_result(repo,operation_id,worker_token,result)
    list(operation_id=operation_id,status=get_validation_run(repo,operation_id)$status)
  },error=function(e){
    message<-conditionMessage(e)
    try(with_write(repo$con,function(){
      run<-get_validation_run(repo,operation_id)
      if(validation_worker_owned(run,worker_token)) {
        for(family in unlist(run$request$families))validation_progress_locked(repo,operation_id,family,"failed",paste("No final result committed:",message))
        validation_progress_locked(repo,operation_id,"run","failed",message)
        record_operation_event_locked(repo,operation_id,"failed","validation-worker",message)
      }
    }),silent=TRUE)
    list(operation_id=operation_id,status="failed",error=message)
  })
}

# Process objects are app-owned, not session-owned. Closing a browser does not
# kill another session's run; supervise terminates children if the app exits.
validation_workers <- new.env(parent=emptyenv())

# Compare queued/unclaimed and append failure under one write reservation.
# A launcher/supervisor must never fail another process's newly acquired claim.
fail_unclaimed_validation_run <- function(repo,operation_id,reason) with_write(repo$con,function(){
  run<-get_validation_run(repo,operation_id)
  if(run$status!="queued"||nrow(run$claim))return(FALSE)
  for(family in unlist(run$request$families))validation_progress_locked(repo,operation_id,family,"failed",reason)
  record_operation_event_locked(repo,operation_id,"failed","validation-launcher",reason)
  TRUE
})

#' Start or poll app-owned supervised validation processes
#' @param repo Open repository handle.
#' @param operation_id Exact queued validation operation ID.
#' @return start_validation_worker() returns operation/status immediately after
#'   launch. refresh_validation_workers() assesses only this app's owned children.
#' @export
start_validation_worker <- function(repo,operation_id) {
  run<-get_validation_run(repo,operation_id)
  key<-paste(repo$root,operation_id,sep="|")
  if(run$status!="queued"||exists(key,envir=validation_workers,inherits=FALSE))return(list(operation_id=operation_id,status=run$status))
  token<-new_id(repo,"worker")
  package_path<-getNamespaceInfo(asNamespace("ecodata"),"path")
  process<-tryCatch(callr::r_bg(function(path,root,id,token){
    if(file.exists(file.path(path,"R","service_validation.R")))pkgload::load_all(path,quiet=TRUE) else library(ecodata)
    ecodata::execute_validation_run(root,id,token)
  },args=list(package_path,repo$root,operation_id,token),libpath=.libPaths(),
    stdout=file.path(repo$root,"logs",paste0(operation_id,".out")),stderr=file.path(repo$root,"logs",paste0(operation_id,".err")),
    supervise=TRUE,user_profile=FALSE,system_profile=FALSE,
    env=c(callr::rcmd_safe_env(),LANG="en_US.UTF-8",LC_ALL=if(.Platform$OS.type=="windows")"English_United States.utf8" else "C.UTF-8")),
    error=function(e){fail_unclaimed_validation_run(repo,operation_id,conditionMessage(e));stop(e)})
  assign(key,list(process=process,token=token,root=repo$root,operation_id=operation_id),envir=validation_workers)
  list(operation_id=operation_id,status=run$status)
}

#' @rdname start_validation_worker
#' @export
refresh_validation_workers <- function(repo) {
  for(key in ls(validation_workers,all.names=TRUE)) {
    child<-get(key,envir=validation_workers)
    if(!identical(child$root,repo$root)||child$process$is_alive())next
    result<-tryCatch(child$process$get_result(),error=identity)
    run<-get_validation_run(repo,child$operation_id)
    if(run$status%in%c("queued","running")&&(!nrow(run$claim)||run$claim$worker_token==child$token)) {
      if(nrow(run$claim))recover_validation_run(repo,child$operation_id,"validation-supervisor") else
        fail_unclaimed_validation_run(repo,child$operation_id,
          if(inherits(result,"error"))conditionMessage(result) else "Worker exited before claiming queued request")
    }
    rm(list=key,envir=validation_workers)
  }
  invisible(NULL)
}
