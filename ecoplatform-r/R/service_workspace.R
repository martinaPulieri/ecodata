#' Register a Shiny upload as persistent input and initial configuration
#'
#' Original browser filenames are retained separately from temporary paths.
#' File sizes are checked against the actual upload; MIME types are not trusted.
#' Registration owns the bytes before a session may delete its upload buffer.
#' The first configuration applies unambiguous technical encoding/separator
#' detection and preserves the detector's evidence. Ambiguities remain explicit.
#' @param repo Open repository handle.
#' @param upload Shiny fileInput data frame (name, size, type, datapath).
#' @param title Human-readable source title.
#' @param actor_id Explicit local operator label, not an authenticated identity.
#' @return List containing version_id, dataset_id, resource_ids and config_id.
#' @export
register_uploaded_inputs <- function(repo, upload, title, actor_id) {
  scalar_text(actor_id, "actor_id")
  scalar_text(title, "title")
  if (!is.data.frame(upload) || !nrow(upload) || !all(c("name", "size", "type", "datapath") %in% names(upload))) stop("Select files before registration")
  actual <- file.info(upload$datapath)$size
  if (anyNA(actual) || anyNA(upload$size) || any(actual != upload$size)) stop("Upload size does not match the received file size")
  registered <- register_input(upload$datapath, list(title = title, source = "local_upload", registered_by = actor_id), repo,
    original_names = upload$name)
  config <- tryCatch({
    resources <- get_input(repo, registered$version_id)$resources
    parsers <- stats::setNames(lapply(resources$original_name, default_parser), resources$resource_id)
    detected <- detect_registered_configuration(repo, registered$version_id, parsers)
    save_configuration(repo, registered$version_id, parsers = detected$parsers, parser_detection = detected$evidence, actor_id = actor_id)
  }, error = function(e) {
    stop("Input retained as ", registered$version_id, "; initial configuration was not saved: ", conditionMessage(e))
  })
  c(registered, list(config_id = config$config_id))
}

#' Execute and record a bounded workspace inspection
#'
#' Records intent, running and terminal events around a read-only lexical preview.
#' Unsupported/unreadable resources produce completed_with_limitations, never a
#' scientific pass. Each explicit run has a distinct request ID.
#' @param repo Open repository handle.
#' @param version_id Exact registered source version.
#' @param config_id Exact configuration revision.
#' @param actor_id Explicit operator label.
#' @return List containing inspection and its operation_id.
#' @export
run_workspace_inspection <- function(repo, version_id, config_id, actor_id) {
  request <- submit_operation(repo, version_id, config_id, "inspect", new_id(repo, "request"), actor_id)
  id <- request$operation_id
  record_operation_event(repo, id, "running", actor_id)
  result <- tryCatch(inspect_input(version_id, config_id, repo), error = function(e) {
    record_operation_event(repo, id, "failed", actor_id, conditionMessage(e))
    stop(e)
  })
  limited <- any(vapply(result$resources, function(x) x$status != "ready", logical(1)))
  record_operation_event(repo, id, if (limited) "completed_with_limitations" else "completed", actor_id,
    if (limited) "One or more resources have explicit inspection limitations" else "Bounded lexical preview; no scientific validation")
  list(inspection = result, operation_id = id)
}

workspace_version_choices <- function(repo) {
  versions <- list_inputs(repo)
  if (!nrow(versions)) return(character())
  titles <- vapply(versions$version_id, function(id) {
    x <- get_input(repo, id)
    title <- x$metadata$title
    if (is.null(title) || !is.character(title) || length(title) != 1L || !nzchar(title)) title <- x$resources$original_name[1]
    paste0(title, " \u00b7 ", substr(id, nchar(id) - 7L, nchar(id)))
  }, character(1))
  stats::setNames(rev(versions$version_id), rev(titles))
}
