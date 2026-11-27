#' Register an idempotent operation request
#'
#' Records intent and a queued event; it does not execute inspection or validation.
#' The same request_id and payload return the existing operation. Reusing a key
#' with a different payload is rejected. Configurations never float to "latest".
#' @param repo Open repository handle.
#' @param version_id Exact source version ID.
#' @param config_id Exact configuration ID belonging to version_id.
#' @param operation_type inspect or validation. Validation routes to a frozen
#'   managed request; neither path performs full-table processing here.
#' @param request_id Caller-generated idempotency key, unique in this repository.
#' @param actor_id Explicit submitting user or worker identity.
#' @param expected_workspace_revision Optional displayed lifecycle revision;
#'   checked for new submissions under the write reservation. An existing
#'   idempotency key remains a history lookup even when the input is removed.
#' @return List with operation_id and current status.
#' @export
submit_operation <- function(repo, version_id, config_id, operation_type, request_id, actor_id,
  expected_workspace_revision = NULL) {
  if(identical(operation_type,"validation"))return(submit_validation_run(repo,version_id,config_id,
    actor_id,request_id,expected_workspace_revision))
  with_write(repo$con, function() submit_operation_locked(repo, version_id, config_id,
    operation_type, request_id, actor_id, expected_workspace_revision))
}

# Caller owns BEGIN IMMEDIATE. Shared with atomic validation request creation.
submit_operation_locked <- function(repo, version_id, config_id, operation_type, request_id, actor_id,
  expected_workspace_revision = NULL, verify_bytes = TRUE) {
  for (name in c("operation_type", "request_id", "actor_id")) scalar_text(get(name), name)
  if (!operation_type %in% c("inspect", "validation")) stop("Unsupported operation_type")
  config <- get_configuration(repo, config_id)
  if (config$version_id != version_id) stop("Configuration belongs to a different version")
  fingerprint <- hash_text(json_text(list(version_id = version_id, config_id = config_id,
    operation_type = operation_type, actor_id = actor_id)))
    old <- DBI::dbGetQuery(repo$con, "SELECT operation_id, request_hash FROM operations WHERE request_id = ?", params = list(request_id))
    if (nrow(old)) {
      if (old$request_hash != fingerprint) stop("request_id was already used for a different request")
      return(list(operation_id = old$operation_id, status = utils::tail(get_operation(repo, old$operation_id)$events$status, 1)))
    }
    assert_workspace_active(repo, version_id, expected_workspace_revision)
    resources <- get_input(repo,version_id)$resources
    if(verify_bytes) {
      verified <- verify_input(repo, version_id)
      if (!verified$ok) stop("Input integrity verification failed")
      resources<-verified$resources
    }
    if (operation_type == "validation" && any(resources$acquisition_status == "incomplete")) stop("Cannot submit incomplete acquisition as a validation input")
    id <- new_id(repo, "operation")
    versions <- lapply(c("ecodata", "DBI", "RSQLite", "digest", "jsonlite", "xml2"), function(p) as.character(utils::packageVersion(p)))
    names(versions) <- c("ecodata", "DBI", "RSQLite", "digest", "jsonlite", "xml2")
    environment <- json_text(list(R = R.version.string, packages = versions,
      code_revision = Sys.getenv("ECODATA_CODE_REVISION", unset = "uncommitted-development; consult source checkout")))
    DBI::dbExecute(repo$con, "INSERT INTO operations VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", params = list(id, version_id, config_id, operation_type, request_id, fingerprint, actor_id, environment, utc_now()))
    DBI::dbExecute(repo$con, "INSERT INTO operation_events VALUES (?, ?, ?, ?, ?, ?, ?)", params = list(new_id(repo, "event"), id, 1L, "queued", actor_id, "submitted", utc_now()))
    list(operation_id = id, status = "queued")
}

#' Append an operation lifecycle event
#'
#' Allowed transitions are queued to running/cancelled/failed/interrupted, then
#' running to completed/completed_with_limitations/failed/interrupted/cancelled.
#' Terminal operations cannot restart; a rerun requires a new request. This API
#' is a trusted-worker audit API and does not certify scientific correctness.
#' Managed validation operations must use the owning validation worker service;
#' the generic audit API cannot advance their lifecycle.
#' @param repo Open repository handle.
#' @param operation_id Registered operation ID.
#' @param status New allowed lifecycle state.
#' @param actor_id Explicit identity recording the event.
#' @param reason Diagnostic explanation, required for failures or interruptions.
#' @return Newly recorded event ID, invisibly.
#' @export
record_operation_event <- function(repo, operation_id, status, actor_id, reason = "") {
  with_write(repo$con, function() {
    if(nrow(DBI::dbGetQuery(repo$con,"SELECT operation_id FROM validation_requests WHERE operation_id=?",params=list(operation_id))))
      stop("Managed validation events require the owning worker service")
    record_operation_event_locked(repo, operation_id, status, actor_id, reason)
  })
}

# Caller owns BEGIN IMMEDIATE; final results and terminal events commit together.
record_operation_event_locked <- function(repo, operation_id, status, actor_id, reason = "") {
  scalar_text(actor_id, "actor_id")
  scalar_text(status, "status")
  scalar_text(reason, "reason", empty = TRUE)
  if (status %in% c("failed", "interrupted", "completed_with_limitations")) scalar_text(reason, "reason")
    operation <- get_operation(repo, operation_id)
    prior <- utils::tail(operation$events, 1)
    transitions <- list(queued = c("running", "cancelled", "failed", "interrupted"),
      running = c("completed", "completed_with_limitations", "failed", "interrupted", "cancelled"))
    if (!status %in% transitions[[prior$status]]) stop("Invalid operation transition")
    id <- new_id(repo, "event")
    DBI::dbExecute(repo$con, "INSERT INTO operation_events VALUES (?, ?, ?, ?, ?, ?, ?)", params = list(id, operation_id, prior$sequence + 1L, status, actor_id, reason, utc_now()))
    invisible(id)
}

#' Retrieve an operation with its immutable context and event history
#' @param repo Open repository handle.
#' @param operation_id Registered operation ID.
#' @return List containing operation row, frozen configuration and ordered events.
#' @export
get_operation <- function(repo, operation_id) {
  row <- one_row(repo, "operations", "operation_id", operation_id)
  list(operation = row, configuration = get_configuration(repo, row$config_id),
    events = DBI::dbGetQuery(repo$con, "SELECT * FROM operation_events WHERE operation_id = ? ORDER BY sequence", params = list(operation_id)))
}

#' List operations and their latest lifecycle state
#' @param repo Open repository handle.
#' @return Data frame in submission order.
#' @export
list_operations <- function(repo) {
  DBI::dbGetQuery(repo$con, "SELECT o.operation_id, o.version_id, o.config_id, o.operation_type, o.request_id, o.created_at, e.status FROM operations o JOIN operation_events e ON o.operation_id = e.operation_id WHERE e.sequence = (SELECT MAX(x.sequence) FROM operation_events x WHERE x.operation_id = o.operation_id) ORDER BY o.rowid")
}

#' List operations requiring worker-liveness assessment
#'
#' Pending does not mean interrupted. Opening a second session must not mark an
#' active worker's operation as failed; scheduler/owner assessment is explicit.
#' @param repo Open repository handle.
#' @return Data frame of queued or running operations.
#' @export
list_pending_operations <- function(repo) {
  rows <- list_operations(repo)
  rows[rows$status %in% c("queued", "running"), , drop = FALSE]
}
