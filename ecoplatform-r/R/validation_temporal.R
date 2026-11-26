# TMP-00--03/TMP-08: lexical structure only. Never parse to Date/POSIXct,
# trim nonblank values, infer calendar ranges or assemble split components.
# These expressions implement the immutable 0.1/1.0 initial definitions.
date_pattern_match <- function(values, pattern) {
  digits <- function(width) paste0("[0-9]{", paste(unlist(width), collapse = ","), "}")
  full <- function(expression, value) grepl(paste0("\\A", expression, "\\z"), value, perl = TRUE)
  kind <- pattern$kind
  if (kind == "split") return(all(vapply(names(values), function(role)
    full(digits(pattern$widths[[role]]), values[[role]]), logical(1))))
  value <- values$value
  if (kind == "single") {
    roles <- switch(pattern$order, YMD = c("year", "month", "day"),
      DMY = c("day", "month", "year"), MDY = c("month", "day", "year"))
    return(full(paste(vapply(roles, function(role) digits(pattern$widths[[role]]), character(1)),
      collapse = pattern$separator), value))
  }
  if (kind == "partial") return(full(if (pattern$format == "YYYY") "[0-9]{4}" else "[0-9]{4}-[0-9]{2}", value))
  if (kind == "timestamp") return(full("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", value))
  if (kind == "interval") return(full("[0-9]{4}-[0-9]{2}-[0-9]{2}/[0-9]{4}-[0-9]{2}-[0-9]{2}", value))
  stop("Unsupported date pattern kind")
}

classify_date_values <- function(values, mapping, spec) {
  blanks <- vapply(values, blank_contract_value, logical(1))
  if (all(blanks)) return(list(status = "missing", candidates = character()))
  split <- length(values) == 3L
  if (split && any(blanks)) return(list(status = "incomplete", candidates = character()))
  candidates <- Filter(function(id) {
    pattern <- spec$patterns$snapshot$patterns[[id]]
    if (identical(pattern$kind, "split") != split) return(FALSE)
    # Recorded order disambiguates year-last expressions only. A structurally
    # explicit year-first expression retains its own order and provenance.
    if (!is.null(mapping$date_order) && pattern$kind == "single" &&
        pattern$order %in% c("DMY", "MDY") && pattern$order != mapping$date_order) return(FALSE)
    date_pattern_match(values, pattern)
  }, as.character(unlist(spec$enabled_patterns)))
  list(status = if (!length(candidates)) "unrecognised" else if (length(candidates) == 1L) "recognised" else "ambiguous",
    candidates = candidates)
}

# A context is scoped to one mapping so independent unreadable siblings never
# invalidate readable dates. The original config hash remains in every record.
date_execution_context <- function(input, mapping) {
  table <- find_prepared_table(input, mapping$table$table_id)
  if (mapping$source == "descriptor" && !is.null(table$declaration)) {
    declaration <- table$declaration
    mapping$evidence <- paste(mapping$evidence, "| Verified descriptor", declaration$descriptor_member,
      "SHA-256", declaration$descriptor_sha256, "member", table$member,
      "eventDate index", mapping$columns$value$position)
  }
  spec <- input$configuration$validation_spec
  if (is.null(spec)) spec <- new_validation_spec(pattern_version = "date-patterns-1.0")
  spec$date_mappings <- list(mapping); spec$linkage_mappings <- list()
  resources <- Filter(function(r) identical(r$resource_id, mapping$table$resource_id), input$resources)
  context <- list(contract_version = "validation-contracts-1.0", version_id = input$version_id,
    config_id = input$config_id, config_hash = input$config_hash, workspace_revision = input$workspace_revision,
    resources = lapply(resources, function(r) r[c("resource_id", "sha256", "original_name", "size_bytes")]),
    validation_spec = spec)
  context$context_hash <- hash_text(json_text(context))
  validate_frozen_context(context)
  contract_copy(context)
}

date_row_values <- function(table, mapping, row) {
  lapply(mapping$columns, function(column) table$data[[column$position + 1L]][[row]])
}

# Unknown populations stay NULL. Explicit not_evaluated rows are emitted only
# when original values and their exact schema are available within the budget.
date_blocked <- function(input, prerequisite, status, reason, limits, context = NULL, cancelled = NULL) {
  mapping <- prerequisite$mapping
  table <- find_prepared_table(input, if (is.null(mapping)) prerequisite$table_id else mapping$table$table_id)
  population <- prerequisite$population_count
  rows <- list(); summary <- NULL
  usable <- !is.null(context) && !is.null(table) && !is.null(population) &&
    identical(table$status, "complete") && contract_equal(table$schema, mapping$table) &&
    population <= limits$max_output_rows && "TMP-00" %in% unlist(context$validation_spec$enabled_rules) &&
    !status %in% c("cancelled", "unreadable", "limited")
  if (usable) {
    rows <- lapply(seq_len(population), function(i) {
      poll_linkage_cancellation(cancelled)
      date_result_from_validated(context, mapping$mapping_id, i, date_row_values(table, mapping, i),
        "not_evaluated", reason = reason)
    })
    summary <- summarise_date_results(context, mapping$mapping_id, rows, population, cancelled)
  }
  list(mapping_id = if (is.null(mapping)) NULL else mapping$mapping_id,
    resource_id = prerequisite$resource_id, table_id = if (is.null(mapping)) prerequisite$table_id else mapping$table$table_id,
    status = status, reason = reason, context = context, population_count = population,
    evaluated_rows = 0L, not_evaluated_rows = population,
    unclassified_rows = if (is.null(population)) NULL else population - length(rows),
    rows = rows, summary = summary, pattern_counts = list(), checks = list())
}

evaluate_date_mapping <- function(input, prerequisite, limits, cancelled) {
  mapping <- prerequisite$mapping
  context <- if (is.null(mapping)) NULL else date_execution_context(input, mapping)
  blocked <- function(status, reason) date_blocked(input, prerequisite, status, reason, limits, context, cancelled)
  tryCatch({
    if (cancelled()) return(blocked("cancelled", "Date recognition cancelled; partial results discarded"))
    if (is.null(mapping) || prerequisite$status != "ready") return(blocked("not_evaluated", prerequisite$reason))
    rules <- c("TMP-00", if (length(mapping$columns) == 3L) "TMP-03" else c("TMP-01", "TMP-02"), "TMP-08")
    disabled <- setdiff(rules, unlist(context$validation_spec$enabled_rules))
    if (length(disabled)) return(blocked("not_evaluated", paste("Disabled mandatory date rules:", paste(disabled, collapse = ", "))))
    table <- find_prepared_table(input, mapping$table$table_id)
    n <- table$population_count
    if (n > limits$max_output_rows) return(blocked("limited", "Whole-run date output row quota exceeded; no partial mapping results retained"))
    rows <- lapply(seq_len(n), function(i) {
      if ((i - 1L) %% 128L == 0L) poll_linkage_cancellation(cancelled)
      values <- date_row_values(table, mapping, i)
      match <- classify_date_values(values, mapping, context$validation_spec)
      date_result_from_validated(context, mapping$mapping_id, i, values, match$status, match$candidates)
    })
    summary <- summarise_date_results(context, mapping$mapping_id, rows, n, cancelled)
    ids <- as.character(unlist(context$validation_spec$enabled_patterns))
    counts <- stats::setNames(as.list(integer(length(ids))), ids)
    for (row in rows) for (candidate in row$candidates) counts[[candidate$pattern_id]] <- counts[[candidate$pattern_id]] + 1L
    checks <- lapply(rules, function(rule) {
      population <- if (rule == "TMP-02") n - summary$counts$missing else n
      new_check_result(context, rule, mapping$table$table_id, "applicable", "completed", population, population)
    })
    poll_linkage_cancellation(cancelled)
    list(mapping_id = mapping$mapping_id, resource_id = mapping$table$resource_id, table_id = mapping$table$table_id,
      status = "completed", reason = "Lexical structure assessed; calendar validity not assessed",
      context = context, population_count = n, evaluated_rows = n, not_evaluated_rows = 0L,
      unclassified_rows = 0L, rows = rows, summary = summary, pattern_counts = counts, checks = checks)
  }, ecodata_read_cancelled = function(e) date_blocked(input, prerequisite, "cancelled", conditionMessage(e), limits, context))
}

evaluate_date_preparation <- function(input, mapping_id = NULL, cancelled = function() FALSE,
  limits = list(max_output_rows = 25000L)) {
  if (!identical(input$contract_version, "validation-preparation-1.0")) stop("Unsupported validation preparation")
  prerequisites <- assess_validation_prerequisites(input)
  selected <- prerequisites$dates
  if (!is.null(mapping_id)) {
    scalar_text(mapping_id, "mapping_id")
    selected <- Filter(function(p) !is.null(p$mapping) && identical(p$mapping$mapping_id, mapping_id), selected)
    if (length(selected) != 1L) {
      if (!cancelled()) stop("Unknown or ambiguous date mapping_id")
      selected <- list(prerequisite_record("TMP-00", "date", "not_evaluated",
        "Cancelled before the requested mapping could be resolved"))
    }
  }
  ids <- vapply(selected, function(p) if (is.null(p$mapping)) "" else p$mapping$mapping_id, character(1))
  collisions <- ids[nzchar(ids) & (duplicated(ids) | duplicated(ids, fromLast = TRUE))]
  remaining <- limits
  mappings <- vector("list", length(selected))
  for (i in seq_along(selected)) {
    p <- selected[[i]]
    if (!is.null(p$mapping) && p$mapping$mapping_id %in% collisions) {
      p$status <- "not_evaluated"; p$reason <- "Effective date mapping ID conflicts with another mapping"
      p$eligible_rows <- 0L
    }
    selected[[i]] <- p
    mappings[[i]] <- evaluate_date_mapping(input, p, remaining, cancelled)
    remaining$max_output_rows <- remaining$max_output_rows - length(mappings[[i]]$rows)
  }
  finish_date_evaluation(list(contract_version = "date-evaluation-1.0", engine_version = "lexical-dates-1.0",
    calendar_validation = FALSE, value_conversion = FALSE, version_id = input$version_id,
    config_id = input$config_id, config_hash = input$config_hash, requested_mapping_id = mapping_id,
    rules_source = if (is.null(input$configuration$validation_spec)) "application_defaults" else "configuration",
    prerequisites = selected, linkage_prerequisites = prerequisites$linkage,
    limits = limits, mappings = mappings))
}

finish_date_evaluation <- function(output) {
  states <- vapply(output$mappings, function(m) m$status, character(1))
  output$status <- if (any(states == "cancelled")) "cancelled" else
    if (length(states) && all(states == "completed")) "completed" else "completed_with_limitations"
  output$contexts <- Filter(Negate(is.null), lapply(output$mappings, function(m) m$context))
  output$context <- if (length(output$contexts) == 1L) output$contexts[[1]] else NULL
  output$result_hash <- NULL
  output$result_hash <- hash_text(json_text(output))
  contract_copy(output)
}
