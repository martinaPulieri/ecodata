# Result constructors validate structure and consistency, not scientific truth.
# They never read tables, recognise a pattern, join data or write to SQLite.
result_base <- function(context, rule_id, kind) {
  validate_frozen_context(context)
  scalar_text(rule_id, "rule_id")
  if (!rule_id %in% unlist(context$validation_spec$enabled_rules)) stop("Unknown or disabled rule")
  list(kind = kind, contract_version = context$contract_version,
    context_hash = context$context_hash, config_id = context$config_id,
    version_id = context$version_id, rule_id = rule_id,
    rule_version = context$validation_spec$rules$snapshot$rule_version,
    rule_catalogue_version = context$validation_spec$rules$version)
}

seal_result <- function(record) {
  record$record_hash <- hash_text(json_text(record))
  contract_copy(record)
}

context_tables <- function(context) {
  spec <- context$validation_spec
  c(lapply(spec$date_mappings, function(x) x$table),
    unlist(lapply(spec$linkage_mappings, function(x) list(x$core$table, x$extension$table)), recursive = FALSE))
}

mapped_contract <- function(context, mapping_id, kind) {
  scalar_text(mapping_id, "mapping_id")
  mappings <- context$validation_spec[[paste0(kind, "_mappings")]]
  matches <- Filter(function(x) identical(x$mapping_id, mapping_id), mappings)
  if (length(matches) != 1L) stop("Unknown ", kind, " mapping_id")
  matches[[1]]
}

row_locator <- function(table_id, number) {
  contract_count(number, "row number")
  if (number < 1) stop("Row number must be positive")
  paste0(table_id, ":row:", format(number, scientific = FALSE, trim = TRUE))
}

blank_contract_value <- function(value) grepl("^[\\h\\v]*$", value, perl = TRUE)

#' Construct a check execution/coverage record without running a check
#' @param context Frozen validation context.
#' @param rule_id Enabled rule identifier.
#' @param table_ids Declared scoped tables; empty for a source-level prerequisite.
#' @param applicability applicable, not_applicable or prerequisites_missing.
#' @param execution_state not_started, running, completed, failed, interrupted or cancelled.
#' @param population_count Nonnegative declared population or NULL when unknown.
#' @param evaluated_count Number actually evaluated, independently of findings.
#' @param reason Required for skipped, failed, interrupted, unknown or incomplete assessments.
#' @return Hashed JSON-compatible check record. Completion never means a scientific pass.
#' @export
new_check_result <- function(context, rule_id, table_ids, applicability, execution_state,
  population_count, evaluated_count, reason = "") {
  base <- result_base(context, rule_id, "check")
  contract_texts(table_ids, "table IDs", TRUE)
  known <- vapply(context_tables(context), function(x) x$table_id, character(1))
  if (anyDuplicated(table_ids) || any(!table_ids %in% known)) stop("Unknown or repeated table ID")
  applicability <- contract_enum(applicability, c("applicable", "not_applicable", "prerequisites_missing"), "applicability")
  execution_state <- contract_enum(execution_state, c("not_started", "running", "completed", "failed", "interrupted", "cancelled"), "execution_state")
  contract_count(evaluated_count, "evaluated population")
  if (!is.null(population_count)) {
    contract_count(population_count, "population")
    if (evaluated_count > population_count) stop("Evaluated count exceeds population")
  }
  if (applicability != "applicable" && (execution_state != "not_started" || evaluated_count != 0)) stop("Unevaluated applicability requires not_started and zero evaluated rows")
  if (execution_state == "not_started" && evaluated_count != 0) stop("not_started cannot contain evaluated rows")
  coverage <- if (is.null(population_count)) "unknown" else if (evaluated_count == population_count) "complete" else if (evaluated_count == 0) "none" else "partial"
  scalar_text(reason, "reason", empty = TRUE)
  if (applicability != "applicable" || execution_state %in% c("failed", "interrupted", "cancelled") ||
      is.null(population_count) || (execution_state == "completed" && coverage != "complete")) scalar_text(reason, "reason")
  seal_result(c(base, list(table_ids = unname(as.list(table_ids)), applicability = applicability,
    execution_state = execution_state, population_count = population_count,
    evaluated_count = evaluated_count, coverage = coverage, reason = reason)))
}

#' Construct one date classification record for one mapped row
#' @param context Frozen validation context.
#' @param mapping_id Date mapping identifier in that context.
#' @param row_number One-based logical data-row number, excluding headers.
#' @param original_values Named character vector/list (value or day/month/year).
#'   Values must be decoded text, including literal NA, whitespace and leading zeros.
#' @param status recognised, ambiguous, unrecognised, missing, incomplete or not_evaluated.
#' @param candidates Character vector of enabled pattern IDs. A unique match
#'   requires one, ambiguity at least two; other statuses require none.
#' @param missing_components Optional split component names; NULL derives only
#'   the blank-component metadata, without constructing a date or matching patterns.
#' @param reason Required when not evaluated.
#' @return Hashed record including original mapping provenance, headers/positions,
#'   values, observed widths and complete candidate pattern definitions.
#' @export
new_date_result <- function(context, mapping_id, row_number, original_values, status,
  candidates = character(), missing_components = NULL, reason = "") {
  validate_frozen_context(context)
  mapping <- mapped_contract(context, mapping_id, "date")
  status <- contract_enum(status, unlist(context$validation_spec$rules$snapshot$date_statuses), "status")
  split <- length(mapping$columns) == 3L
  if (!mapping$confirmed && status != "not_evaluated") stop("Mapping must be confirmed before classification")
  values <- as.list(original_values)
  if (is.null(names(values)) || anyDuplicated(names(values)) || !setequal(names(values), names(mapping$columns))) stop("Original values must bind the mapped component roles")
  lapply(values, function(value) scalar_text(value, "original text", empty = TRUE))
  blanks <- names(values)[vapply(values, blank_contract_value, logical(1))]
  if (status == "missing" && length(blanks) != length(values)) stop("missing requires only empty/whitespace values")
  if (status == "incomplete" && (!split || !length(blanks) || length(blanks) == 3L)) stop("incomplete requires one or two missing split components")
  if (status %in% c("recognised", "ambiguous", "unrecognised") && length(blanks)) stop("Nonmissing classification contains missing components")
  if (split && status == "ambiguous") stop("Named split components cannot have ambiguous order")
  expected_missing <- if (split && status %in% c("missing", "incomplete")) blanks else character()
  if (is.null(missing_components)) missing_components <- expected_missing
  contract_texts(missing_components, "missing components", TRUE)
  if (anyDuplicated(missing_components) || !setequal(missing_components, expected_missing)) stop("Missing component metadata disagrees with original values")
  contract_texts(candidates, "candidates", TRUE)
  if (anyDuplicated(candidates) || any(!candidates %in% unlist(context$validation_spec$enabled_patterns))) stop("Unknown, disabled or repeated candidate pattern")
  if ((status == "recognised" && length(candidates) != 1L) ||
      (status == "ambiguous" && length(candidates) < 2L) ||
      (!status %in% c("recognised", "ambiguous") && length(candidates))) stop("Invalid candidate cardinality for date status")
  patterns <- lapply(candidates, function(id) context$validation_spec$patterns$snapshot$patterns[[id]])
  if (length(patterns) && any(vapply(patterns, function(x) identical(x$kind, "split"), logical(1)) != split)) stop("Candidate pattern kind disagrees with mapped components")
  scalar_text(reason, "reason", empty = TRUE)
  if (status == "not_evaluated") scalar_text(reason, "reason")
  rule <- if (status == "not_evaluated") "TMP-00" else if (split) "TMP-03" else if (status == "missing") "TMP-01" else "TMP-02"
  seal_result(c(result_base(context, rule, "date"), list(mapping_id = mapping_id,
    table_id = mapping$table$table_id, row_number = row_number,
    row_locator = row_locator(mapping$table$table_id, row_number), mapping = mapping,
    date_role = mapping$date_role, original_values = values, observed_widths = lapply(values, nchar),
    status = status, missing_components = as.list(missing_components), reason = reason,
    pattern_catalogue_version = context$validation_spec$patterns$version,
    candidates = lapply(seq_along(candidates), function(i) list(pattern_id = candidates[[i]], pattern = patterns[[i]])))))
}

#' Construct one mutually exclusive measurement linkage outcome
#' @param context Frozen validation context.
#' @param mapping_id Descriptor linkage mapping identifier.
#' @param row_number One-based logical extension data-row number.
#' @param original_reference Unmodified decoded reference text.
#' @param outcome linked, ambiguous, missing_reference, unresolved_reference or not_evaluated.
#' @param candidate_core_rows Distinct one-based core-row numbers; exactly one
#'   for linked, at least two for ambiguous, none for the other outcomes.
#' @param reason Required for not_evaluated.
#' @return Hashed result with source/target table IDs and candidate row locators.
#' @export
new_linkage_result <- function(context, mapping_id, row_number, original_reference,
  outcome, candidate_core_rows = numeric(), reason = "") {
  validate_frozen_context(context)
  mapping <- mapped_contract(context, mapping_id, "linkage")
  outcome <- contract_enum(outcome, unlist(context$validation_spec$rules$snapshot$linkage_outcomes), "outcome")
  scalar_text(original_reference, "original reference", empty = TRUE)
  if (!mapping$confirmed && outcome != "not_evaluated") stop("Linkage declaration must be confirmed")
  missing <- blank_contract_value(original_reference)
  if (outcome == "missing_reference" && !missing) stop("missing reference must be empty/whitespace")
  if (outcome %in% c("linked", "ambiguous", "unresolved_reference") && missing) stop("Nonmissing outcome has a missing reference")
  if (!is.numeric(candidate_core_rows) || anyDuplicated(candidate_core_rows)) stop("Candidate core rows must be distinct numeric positions")
  candidates <- lapply(unname(candidate_core_rows), function(x) row_locator(mapping$core$table$table_id, x))
  if ((outcome == "linked" && length(candidates) != 1L) || (outcome == "ambiguous" && length(candidates) < 2L) ||
      (!outcome %in% c("linked", "ambiguous") && length(candidates))) stop("Invalid candidate cardinality for linkage outcome")
  scalar_text(reason, "reason", empty = TRUE)
  if (outcome == "not_evaluated") scalar_text(reason, "reason")
  rule <- switch(outcome, linked = "LNK-05", ambiguous = "LNK-06", missing_reference = "LNK-04", unresolved_reference = "LNK-05", not_evaluated = "LNK-01")
  seal_result(c(result_base(context, rule, "linkage"), list(mapping_id = mapping_id,
    table_id = mapping$extension$table$table_id, target_table_id = mapping$core$table$table_id,
    row_number = row_number, row_locator = row_locator(mapping$extension$table$table_id, row_number),
    original_reference = original_reference, outcome = outcome,
    candidate_core_locators = candidates, mapping = mapping, reason = reason)))
}

#' Construct a diagnostic finding with one or many source rows
#' @param context Frozen validation context.
#' @param rule_id Enabled rule with a declared finding severity.
#' @param table_id Exact table ID in the mapping declarations.
#' @param row_numbers Distinct positive source-row positions.
#' @param original_values Character vector with one unmodified value per row.
#' @param reason Explanation/evidence for the diagnostic.
#' @param mapping_id Optional exact confirmed linkage mapping; required when more
#'   than one declaration could apply to the target table.
#' @return Hashed finding. A repeated-key group is one finding with multiple targets.
#' @export
new_validation_finding <- function(context, rule_id, table_id, row_numbers, original_values, reason,
  mapping_id = NULL) {
  base <- result_base(context, rule_id, "finding")
  scalar_text(table_id, "table_id")
  severity <- context$validation_spec$rules$snapshot$rules[[rule_id]]$severity
  if (is.null(severity)) stop("Rule defines a classification or technical state, not a finding severity")
  role <- switch(rule_id, "LNK-02" = "core", "LNK-03" = "core", "LNK-04" = "extension",
    "LNK-05" = "extension", "LNK-06" = "extension", "LNK-07" = "core", "LNK-08" = "either")
  if (is.null(role)) stop("Rule has no declared linkage finding contract")
  links <- Filter(function(x) isTRUE(x$confirmed) &&
    ((role %in% c("core", "either") && identical(x$core$table$table_id, table_id)) ||
     (role %in% c("extension", "either") && identical(x$extension$table$table_id, table_id))),
    context$validation_spec$linkage_mappings)
  if (!is.null(mapping_id)) {
    scalar_text(mapping_id, "mapping_id")
    links <- Filter(function(x) identical(x$mapping_id, mapping_id), links)
  }
  if (length(links) != 1L) stop("Finding requires one confirmed linkage mapping for the target; specify mapping_id when necessary")
  mapping <- links[[1]]
  column <- if (identical(mapping$core$table$table_id, table_id)) mapping$core$column else mapping$extension$column
  contract_texts(original_values, "original values", TRUE)
  if (!is.numeric(row_numbers) || !length(row_numbers) || anyDuplicated(row_numbers) || length(row_numbers) != length(original_values)) stop("Finding rows and values must bind once per row")
  row_numbers <- unname(row_numbers); original_values <- unname(original_values)
  if (rule_id == "LNK-03" && length(row_numbers) < 2L) stop("Repeated-key findings require at least two rows")
  if (!rule_id %in% c("LNK-03", "LNK-07") && length(row_numbers) != 1L) stop("This diagnostic requires exactly one source row")
  blanks <- vapply(original_values, blank_contract_value, logical(1))
  if (rule_id %in% c("LNK-02", "LNK-04") && !all(blanks)) stop("Missing-key findings require empty/whitespace values")
  if (rule_id %in% c("LNK-03", "LNK-05", "LNK-06", "LNK-08") && any(blanks)) stop("This diagnostic requires nonmissing original values")
  if (rule_id == "LNK-03" && length(unique(original_values)) != 1L) stop("Repeated-key group values must be exactly the same")
  if (rule_id == "LNK-08" && identical(original_values, trimws(original_values, whitespace = "[\\h\\v]"))) stop("Whitespace diagnostic requires leading or trailing whitespace")
  scalar_text(reason, "reason")
  seal_result(c(base, list(mapping_id = mapping$mapping_id, mapping = mapping, table_id = table_id,
    column = column, row_numbers = as.list(row_numbers),
    row_locators = lapply(row_numbers, function(x) row_locator(table_id, x)),
    original_values = as.list(original_values), severity = severity, reason = reason)))
}

# Portable records must satisfy their typed contract as well as their digest.
# A recomputed unkeyed hash cannot legitimise contradictory source identities,
# mapping provenance, candidate definitions or rule/row locator metadata.
validate_row_result <- function(context, mapping_id, record, kind) {
  payload <- record; payload$record_hash <- NULL
  if (!identical(record$record_hash, hash_text(json_text(payload)))) stop("Result record hash mismatch")
  if (!identical(record$context_hash, context$context_hash) || !identical(record$kind, kind) ||
      !identical(record$mapping_id, mapping_id)) stop("Result belongs to another context or mapping")
  if (kind == "date") {
    ids <- vapply(record$candidates, function(x) scalar_text(x$pattern_id, "candidate pattern ID"), character(1))
    rebuilt <- new_date_result(context, mapping_id, record$row_number, record$original_values,
      record$status, ids, as.character(unlist(record$missing_components)), record$reason)
  } else {
    mapping <- mapped_contract(context, mapping_id, "linkage")
    prefix <- paste0(mapping$core$table$table_id, ":row:")
    rows <- vapply(record$candidate_core_locators, function(locator) {
      scalar_text(locator, "candidate row locator")
      if (!startsWith(locator, prefix)) stop("Candidate row identity disagrees with its target table")
      suffix <- substring(locator, nchar(prefix) + 1L)
      if (!grepl("^[1-9][0-9]*$", suffix)) stop("Invalid candidate row identity")
      as.numeric(suffix)
    }, numeric(1))
    rebuilt <- new_linkage_result(context, mapping_id, record$row_number, record$original_reference,
      record$outcome, rows, record$reason)
  }
  if (!contract_equal(record, rebuilt)) stop("Result identity or payload disagrees with its frozen context")
  invisible(record)
}
summarise_row_contracts <- function(context, mapping_id, results, population_count, kind, field, states, cancelled=NULL) {
  validate_frozen_context(context)
  mapped_contract(context, mapping_id, kind)
  contract_count(population_count, "population")
  if (!is.list(results) || length(results) != population_count) stop("Result count must equal the declared population; include explicit not_evaluated rows")
  poll_linkage_cancellation(cancelled)
  rows <- numeric(length(results)); labels <- character(length(results))
  for (i in seq_along(results)) {
    if((i-1L)%%128L==0L)poll_linkage_cancellation(cancelled)
    record <- results[[i]]
    validate_row_result(context, mapping_id, record, kind)
    contract_count(record$row_number, "row number")
    if (record$row_number < 1 || record$row_number > population_count) stop("Result row is outside the population")
    rows[[i]] <- record$row_number; labels[[i]] <- record[[field]]
  }
  poll_linkage_cancellation(cancelled)
  if (anyDuplicated(rows)) stop("Each source row must appear exactly once per mapping")
  if (any(!labels %in% states)) stop("Unknown row outcome")
  counts <- stats::setNames(lapply(states, function(x) sum(labels == x)), states)
  contract_copy(list(context_hash = context$context_hash, mapping_id = mapping_id,
    population_count = population_count, counts = counts))
}

#' Reconcile one result per source row for one mapping
#' @param context Frozen validation context.
#' @param mapping_id Exact date or linkage mapping identifier.
#' @param results Typed records for this context/mapping, including not_evaluated rows.
#' @param population_count Exact number of source rows; zero is supported.
#' @param cancelled Optional cooperative function for linkage summaries; NULL
#'   leaves existing summary behaviour unchanged.
#' @return JSON-compatible mutually exclusive status counts. Missing or duplicate
#'   rows and mixed source contexts are rejected instead of silently counted.
#' @export
summarise_date_results <- function(context, mapping_id, results, population_count) {
  summarise_row_contracts(context, mapping_id, results, population_count, "date", "status",
    unlist(context$validation_spec$rules$snapshot$date_statuses))
}

#' @rdname summarise_date_results
#' @export
summarise_linkage_results <- function(context, mapping_id, results, population_count, cancelled=NULL) {
  summarise_row_contracts(context, mapping_id, results, population_count, "linkage", "outcome",
    unlist(context$validation_spec$rules$snapshot$linkage_outcomes),cancelled)
}
