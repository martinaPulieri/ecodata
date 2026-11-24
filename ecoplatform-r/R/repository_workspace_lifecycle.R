#' Read a source version's current workspace membership
#' @param repo Open repository handle.
#' @param version_id Exact source version, including all its resources.
#' @return List containing state (active/removed) and monotonic revision. A
#'   version without events is active at revision zero.
#' @export
get_workspace_state <- function(repo, version_id) {
  one_row(repo, "dataset_versions", "version_id", version_id)
  row <- DBI::dbGetQuery(repo$con, "SELECT state, revision FROM workspace_lifecycle_events WHERE version_id = ? ORDER BY revision DESC LIMIT 1", params = list(version_id))
  if (!nrow(row)) return(list(state = "active", revision = 0L))
  as.list(row)
}

#' List source versions by workspace membership
#' @param repo Open repository handle.
#' @param state active (default), removed or all.
#' @return Version data frame with workspace_state and workspace_revision.
#'   list_inputs() remains the complete immutable source catalogue.
#' @export
list_workspace_inputs <- function(repo, state = c("active", "removed", "all")) {
  state <- match.arg(state)
  rows <- DBI::dbGetQuery(repo$con, "SELECT v.version_id, v.dataset_id, v.parent_version_id, v.created_at, COALESCE(e.state, 'active') AS workspace_state, COALESCE(e.revision, 0) AS workspace_revision FROM dataset_versions v LEFT JOIN workspace_lifecycle_events e ON e.version_id = v.version_id AND e.revision = (SELECT MAX(x.revision) FROM workspace_lifecycle_events x WHERE x.version_id = v.version_id) ORDER BY v.rowid")
  if (state == "all") rows else rows[rows$workspace_state == state, , drop = FALSE]
}

#' List the immutable removal and restoration audit trail
#' @param repo Open repository handle.
#' @param version_id Exact source version.
#' @return Events ordered by lifecycle revision.
#' @export
list_workspace_events <- function(repo, version_id) {
  one_row(repo, "dataset_versions", "version_id", version_id)
  DBI::dbGetQuery(repo$con, "SELECT * FROM workspace_lifecycle_events WHERE version_id = ? ORDER BY revision", params = list(version_id))
}

# Zero is a valid initial lifecycle revision, unlike configuration revisions.
workspace_revision <- function(value) {
  if (!is.numeric(value) || length(value) != 1L || is.na(value) || !is.finite(value) || value < 0 || value > .Machine$integer.max || value != floor(value)) stop("Invalid workspace revision")
  as.integer(value)
}

# Called again inside the writer reservation. A remove/restore cycle must not
# revive an old form merely because the version is active again (the ABA case).
assert_workspace_active <- function(repo, version_id, expected_revision = NULL) {
  current <- get_workspace_state(repo, version_id)
  if (!is.null(expected_revision) && current$revision != workspace_revision(expected_revision)) stop("stale workspace revision; reload before continuing", call. = FALSE)
  if (current$state != "active") stop("Input is removed from the workspace; restore it first", call. = FALSE)
  current$revision
}

#' Remove or restore one uploaded source version reversibly
#'
#' Appends an audit event under BEGIN IMMEDIATE. Never deletes files, source
#' manifests, configurations or operation history. Removal is rejected while
#' any operation for this version is queued/running. Repeating an identical
#' request returns its original event; reuse with another payload is rejected.
#' @param repo Open repository handle.
#' @param version_id Exact source version; all its resources move together.
#' @param state Target membership: removed or active (restore).
#' @param expected_revision Displayed lifecycle revision, including zero.
#' @param request_id Unique caller-generated idempotency key.
#' @param actor_id Explicit operator label; not authenticated identity.
#' @param reason Optional explanation retained in history.
#' @return Original or newly appended event as a named list.
#' @export
set_workspace_state <- function(repo, version_id, state, expected_revision,
  request_id, actor_id, reason = "") {
  state <- match.arg(state, c("removed", "active"))
  expected_revision <- workspace_revision(expected_revision)
  scalar_text(request_id, "request_id"); scalar_text(actor_id, "actor_id")
  scalar_text(reason, "reason", empty = TRUE)
  scalar_text(version_id, "version_id")
  fingerprint <- hash_text(json_text(list(version_id = version_id, state = state,
    expected_revision = expected_revision, actor_id = actor_id, reason = reason)))
  with_write(repo$con, function() {
    old <- DBI::dbGetQuery(repo$con, "SELECT * FROM workspace_lifecycle_events WHERE request_id = ?", params = list(request_id))
    if (nrow(old)) {
      if (old$request_hash != fingerprint) stop("request_id was already used for a different request")
      return(as.list(old))
    }
    current <- get_workspace_state(repo, version_id)
    if (current$revision != expected_revision) stop("stale workspace revision; reload before continuing")
    if (current$state == state) stop("Input is already in the requested workspace state")
    if (state == "removed") {
      pending <- list_pending_operations(repo)
      if (any(pending$version_id == version_id)) stop("Cannot remove input with queued or running operations")
    }
    id <- new_id(repo, "workspace_event")
    DBI::dbExecute(repo$con, "INSERT INTO workspace_lifecycle_events VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
      params = list(id, version_id, current$revision + 1L, state, request_id, fingerprint, actor_id, reason, utc_now()))
    as.list(one_row(repo, "workspace_lifecycle_events", "event_id", id))
  })
}
