#' Declare a source-scoped table schema for validation contracts
#'
#' This declaration does not read or certify a table. The future validation
#' reader must verify the member, headers and positions against the source.
#' Duplicate and empty headers are retained; positions disambiguate them.
#' @param version_id Immutable source version ID.
#' @param resource_id Registered resource ID within that version.
#' @param headers Character vector of original headers, in original order.
#' @param member Archive member path, or NULL for a standalone delimited table.
#' @return JSON-compatible table declaration using zero-based positions.
#' @export
new_validation_table <- function(version_id, resource_id, headers, member = NULL) {
  scalar_text(version_id, "version_id"); scalar_text(resource_id, "resource_id")
  contract_texts(headers, "headers", empty = TRUE)
  if (!length(headers)) stop("A table requires at least one column")
  if (!is.null(member)) {
    scalar_text(member, "member")
    check_archive_entries(data.frame(Name = member, Length = 0))
  }
  contract_copy(list(version_id = version_id, resource_id = resource_id,
    table_id = paste0(resource_id, ":", if (is.null(member)) "table" else member),
    member = member, headers = unname(as.list(headers))))
}

validate_table_contract <- function(table) {
  rebuilt <- new_validation_table(table$version_id, table$resource_id, unlist(table$headers, use.names = FALSE), table$member)
  if (!contract_equal(table, rebuilt)) stop("Invalid table declaration")
  invisible(table)
}

column_contract <- function(table, position) {
  contract_count(position, "column position")
  if (position >= length(table$headers)) stop("Column position is outside the declared table")
  list(position = position, original_header = table$headers[[position + 1]])
}

#' Declare one date role and its field or split component assignments
#' @param table Table declaration from new_validation_table().
#' @param mapping_id Stable identifier unique within one validation specification.
#' @param date_role Explicit role, for example sampling_date or analysis_date.
#' @param columns Named numeric zero-based positions: value, or day/month/year.
#'   Component roles are names, regardless of physical column order.
#' @param source descriptor, user or suggested.
#' @param actor_id Explicit operator/system provenance label.
#' @param evidence Explanation supporting the mapping declaration.
#' @param confirmed Logical declaration/confirmation flag. Suggestions cannot
#'   be confirmed; construct a user mapping after explicit confirmation.
#' @param date_order NULL, DMY, MDY or YMD for a single field.
#' @param date_order_evidence Required explanation when an order is documented.
#' @return Mapping with original headers, positions and provenance. It is not
#'   evidence that the source exists or that a value is a valid calendar date.
#' @export
new_date_mapping <- function(table, mapping_id, date_role, columns, source,
  actor_id, evidence, confirmed = FALSE, date_order = NULL, date_order_evidence = "") {
  validate_table_contract(table)
  scalar_text(mapping_id, "mapping_id"); scalar_text(date_role, "date_role")
  scalar_text(actor_id, "actor_id"); scalar_text(evidence, "mapping evidence")
  source <- contract_enum(source, c("descriptor", "user", "suggested"), "source")
  if (!is.logical(confirmed) || length(confirmed) != 1L || is.na(confirmed)) stop("Invalid confirmed flag")
  if (source == "suggested" && confirmed) stop("A suggested mapping cannot claim confirmation")
  if (!is.numeric(columns) || is.null(names(columns)) || anyDuplicated(names(columns)) ||
      !(setequal(names(columns), "value") || setequal(names(columns), c("day", "month", "year")))) stop("Columns require value or named day/month/year roles")
  if (anyDuplicated(columns)) stop("Component columns must be distinct")
  refs <- lapply(columns, function(position) column_contract(table, position))
  scalar_text(date_order_evidence, "date order evidence", empty = TRUE)
  if (!is.null(date_order)) {
    if (length(columns) != 1L) stop("Split roles already specify component order")
    date_order <- contract_enum(date_order, c("DMY", "MDY", "YMD"), "date_order")
    scalar_text(date_order_evidence, "date order evidence")
  } else if (nzchar(date_order_evidence)) stop("Date order evidence requires a date order")
  contract_copy(list(mapping_id = mapping_id, table = table, date_role = date_role,
    columns = refs, source = source, actor_id = actor_id, evidence = evidence,
    confirmed = confirmed, date_order = date_order, date_order_evidence = date_order_evidence))
}

validate_date_mapping <- function(mapping) {
  positions <- vapply(mapping$columns, function(x) x$position, numeric(1))
  rebuilt <- new_date_mapping(mapping$table, mapping$mapping_id, mapping$date_role, positions,
    mapping$source, mapping$actor_id, mapping$evidence, mapping$confirmed, mapping$date_order, mapping$date_order_evidence)
  if (!contract_equal(mapping, rebuilt)) stop("Invalid date mapping or original table headers")
  invisible(mapping)
}

#' Declare the core/reference pair from one archive descriptor
#' @param core_table,extension_table Distinct archive table declarations belonging
#'   to the same source version and resource.
#' @param core_id_position,extension_reference_position Zero-based descriptor indices.
#' @param mapping_id Unique mapping identifier within the specification.
#' @param actor_id Explicit provenance label.
#' @param evidence Exact declaration evidence; no inferred occurrenceID substitution.
#' @param confirmed Whether the supported relationship has been confirmed.
#' @return Descriptor linkage declaration; no joins or linkage checks are executed.
#' @export
new_linkage_mapping <- function(core_table, core_id_position, extension_table,
  extension_reference_position, mapping_id, actor_id, evidence, confirmed = FALSE) {
  validate_table_contract(core_table); validate_table_contract(extension_table)
  if (is.null(core_table$member) || is.null(extension_table$member) ||
      core_table$version_id != extension_table$version_id || core_table$resource_id != extension_table$resource_id) stop("Linkage must remain within one archive")
  if (core_table$table_id == extension_table$table_id) stop("Core and extension must be different tables")
  scalar_text(mapping_id, "mapping_id"); scalar_text(actor_id, "actor_id"); scalar_text(evidence, "descriptor evidence")
  if (!is.logical(confirmed) || length(confirmed) != 1L || is.na(confirmed)) stop("Invalid confirmed flag")
  contract_copy(list(mapping_id = mapping_id, source = "descriptor", actor_id = actor_id,
    evidence = evidence, confirmed = confirmed,
    core = list(table = core_table, column = column_contract(core_table, core_id_position)),
    extension = list(table = extension_table, column = column_contract(extension_table, extension_reference_position))))
}

validate_linkage_mapping <- function(mapping) {
  rebuilt <- new_linkage_mapping(mapping$core$table, mapping$core$column$position,
    mapping$extension$table, mapping$extension$column$position, mapping$mapping_id,
    mapping$actor_id, mapping$evidence, mapping$confirmed)
  if (!contract_equal(mapping, rebuilt)) stop("Invalid linkage mapping")
  invisible(mapping)
}

#' Freeze validation definitions and mapping declarations
#' @param date_mappings List of date mapping declarations, including suggestions.
#' @param linkage_mappings List of descriptor linkage declarations.
#' @param enabled_rules,enabled_patterns Character vectors of catalogue IDs;
#'   NULL enables all defined entries. Empty vectors explicitly enable none.
#' @return Specification containing complete catalogue snapshots and SHA-256
#'   hashes of canonical JSON. Does not execute any rules or infer any mappings.
#' @export
new_validation_spec <- function(date_mappings = list(), linkage_mappings = list(),
  enabled_rules = NULL, enabled_patterns = NULL) {
  if (!is.list(date_mappings) || !is.list(linkage_mappings)) stop("Mappings must be lists")
  lapply(date_mappings, validate_date_mapping); lapply(linkage_mappings, validate_linkage_mapping)
  mappings <- c(date_mappings, linkage_mappings)
  ids <- vapply(mappings, function(x) x$mapping_id, character(1))
  if (anyDuplicated(ids)) stop("Each mapping_id must be unique")
  tables <- c(lapply(date_mappings, function(x) x$table),
    unlist(lapply(linkage_mappings, function(x) list(x$core$table, x$extension$table)), recursive = FALSE))
  if (length(tables)) {
    versions <- unique(vapply(tables, function(x) x$version_id, character(1)))
    if (length(versions) > 1L) stop("Mappings must belong to one source version")
    seen <- list()
    for (table in tables) {
      prior <- seen[[table$table_id]]
      if (!is.null(prior) && !contract_equal(prior, table)) stop("Conflicting table declarations")
      seen[[table$table_id]] <- table
    }
  }
  rules <- validation_rules(); patterns <- date_patterns()
  if (is.null(enabled_rules)) enabled_rules <- names(rules$rules)
  if (is.null(enabled_patterns)) enabled_patterns <- names(patterns$patterns)
  contract_texts(enabled_rules, "enabled rules", TRUE); contract_texts(enabled_patterns, "enabled patterns", TRUE)
  if (anyDuplicated(enabled_rules) || any(!enabled_rules %in% names(rules$rules))) stop("Unknown or repeated rule ID")
  if (anyDuplicated(enabled_patterns) || any(!enabled_patterns %in% names(patterns$patterns))) stop("Unknown or repeated pattern ID")
  contract_copy(list(contract_version = "validation-contracts-1.0", rules = catalogue_snapshot(rules),
    patterns = catalogue_snapshot(patterns), enabled_rules = unname(as.list(enabled_rules)), enabled_patterns = unname(as.list(enabled_patterns)),
    date_mappings = unname(date_mappings), linkage_mappings = unname(linkage_mappings)))
}

validate_validation_spec <- function(spec, version_id = NULL, resource_ids = NULL) {
  rebuilt <- new_validation_spec(spec$date_mappings, spec$linkage_mappings,
    as.character(unlist(spec$enabled_rules)), as.character(unlist(spec$enabled_patterns)))
  if (!contract_equal(spec, rebuilt)) stop("Validation catalogue snapshot/hash or contract mismatch")
  tables <- c(lapply(spec$date_mappings, function(x) x$table),
    unlist(lapply(spec$linkage_mappings, function(x) list(x$core$table, x$extension$table)), recursive = FALSE))
  for (table in tables) {
    if (!is.null(version_id) && table$version_id != version_id) stop("Mapping belongs to a different version")
    if (!is.null(resource_ids) && !table$resource_id %in% resource_ids) stop("Mapping binds an unknown resource")
  }
  invisible(spec)
}
