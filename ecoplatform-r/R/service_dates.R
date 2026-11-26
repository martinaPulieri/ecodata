#' Recognise lexical date patterns without changing inputs or saving results
#'
#' Executes TMP-00--03/TMP-08 independently for each confirmed field/group or
#' usable descriptor eventDate declaration. Original values, ambiguity, mapping
#' evidence, catalogue definitions and exact source/configuration hashes remain
#' attached to typed records. Calendar validity and conversion are not assessed.
#' @param repo Open repository handle.
#' @param version_id Exact active immutable source version.
#' @param config_id Exact configuration belonging to that version.
#' @param mapping_id Optional exact saved, suggested or descriptor mapping ID.
#' @param cancelled Cooperative function returning one nonmissing logical flag.
#' @param max_output_rows Maximum emitted row records across all date mappings
#'   (default 25000). Over-budget mappings have explicit unevaluated coverage.
#' @param expected_workspace_revision Optional displayed lifecycle revision.
#' @return date-evaluation-1.0 containing independent per-mapping rows, status
#'   and pattern counts, coverage/checks and frozen contexts. Unknown populations
#'   remain NULL. Cancellation discards partial output. No configurations,
#'   operations or scientific results are saved. Invalid arguments/stale source
#'   selections raise errors; unreadable resources remain scoped limitations.
#' @export
run_date_validation <- function(repo, version_id, config_id, mapping_id = NULL,
  cancelled = function() FALSE, max_output_rows = 25000L, expected_workspace_revision = NULL) {
  if (!is.function(cancelled)) stop("cancelled must be a function")
  cancellation_requested <- FALSE
  cancel <- function() {
    if (cancellation_requested) return(TRUE)
    flag <- cancelled()
    if (!is.logical(flag) || length(flag) != 1L || is.na(flag)) stop("Invalid cancellation flag")
    cancellation_requested <<- flag
    flag
  }
  limits <- list(max_output_rows = integer_bound(max_output_rows, "max_output_rows", 1000000L))
  input <- read_validation_tables(repo, version_id, config_id, cancelled = cancel,
    expected_workspace_revision = expected_workspace_revision)
  output <- evaluate_date_preparation(input, mapping_id, cancel, limits)
  # A resource modified during execution must not leave stale classifications.
  after <- verify_input(repo, version_id)$resources
  bad <- union(after$resource_id[is.na(after$ok) | !after$ok],
    setdiff(vapply(input$resources, function(r) r$resource_id, character(1)), after$resource_id))
  for (i in seq_along(output$mappings)) if (any(output$mappings[[i]]$resource_id %in% bad)) {
    p <- output$prerequisites[[i]]
    p$status <- "not_evaluated"; p$eligible_rows <- 0L
    p["population_count"] <- list(NULL)
    p$reason <- "Source integrity changed during date recognition"
    output$prerequisites[[i]] <- p
    output$mappings[[i]] <- date_blocked(input, p, "unreadable", p$reason, limits, output$mappings[[i]]$context)
  }
  output$linkage_prerequisites <- lapply(output$linkage_prerequisites, function(p) {
    if (p$resource_id %in% bad) {
      p$status <- "not_evaluated"; p$eligible_rows <- 0L
      p["population_count"] <- list(NULL)
      p$reason <- "Source integrity changed during date recognition"
    }
    p
  })
  assert_workspace_active(repo, version_id, input$workspace_revision)
  if (cancel()) for (i in seq_along(output$mappings)) output$mappings[[i]] <- date_blocked(input,
    output$prerequisites[[i]], "cancelled", "Date recognition cancelled before return; partial results discarded",
    limits, output$mappings[[i]]$context)
  finish_date_evaluation(output)
}
