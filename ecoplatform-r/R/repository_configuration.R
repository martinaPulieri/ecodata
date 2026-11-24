#' Append a complete configuration snapshot
#'
#' Snapshots bind exact resource IDs, explicit parser settings, supplied metadata
#' and a schema declaration to one immutable input version. No values are inferred.
#' Every edit must supply a full snapshot, not a partial patch. NULL expected
#' revision means "create the first revision only"; subsequent edits require the
#' displayed revision number. Changes are serialised using BEGIN IMMEDIATE.
#' @param repo Open repository handle.
#' @param version_id Source version ID.
#' @param parsers Named list of full parser settings, one per resource. NULL uses
#'   recorded defaults: UTF-8, comma (tab for TSV), decimal point, double quotes.
#'   For ZIP resources the immutable archive descriptor supplies member settings;
#'   per-resource parser overrides are not supported.
#' @param metadata JSON-compatible list of supplied interpretation metadata.
#' @param schema List with profile_id, confirmed (logical) and evidence (string).
#' @param expected_revision NULL for first revision or exact current number.
#' @param actor_id Explicit identity recording the revision.
#' @param parser_detection Optional named per-resource detection evidence. Each
#'   entry must match that resource's immutable byte hash. Manual edits may
#'   preserve this evidence without claiming their overrides were detected.
#' @param expected_workspace_revision Optional displayed lifecycle revision.
#'   NULL captures current membership at entry; writes recheck it atomically.
#' @return Snapshot including config_id, revision, hash and complete payload.
#' @export
save_configuration <- function(repo, version_id, parsers = NULL, metadata = list(),
  schema = list(profile_id = "generic_tabular", confirmed = FALSE, evidence = ""),
  expected_revision = NULL, actor_id, parser_detection = list(), expected_workspace_revision = NULL) {
  scalar_text(actor_id, "actor_id")
  membership <- assert_workspace_active(repo, version_id, expected_workspace_revision)
  resources <- get_input(repo, version_id)$resources
  defaults <- stats::setNames(lapply(resources$original_name, default_parser), resources$resource_id)
  if (is.null(parsers)) parsers <- defaults
  if (!is.list(parsers) || !setequal(names(parsers), resources$resource_id) || anyDuplicated(names(parsers))) stop("Parsers must bind each resource exactly once")
  parsers <- lapply(parsers, validate_parser)
  for (i in which(tolower(tools::file_ext(resources$original_name)) == "zip")) {
    rid <- resources$resource_id[i]
    if (json_text(parsers[[rid]]) != json_text(defaults[[rid]])) stop("ZIP member parser settings come from the immutable descriptor")
  }
  if (!is.list(metadata)) stop("metadata must be a list")
  if (!is.list(parser_detection)) stop("parser_detection must be a list")
  if (length(parser_detection)) {
    if (is.null(names(parser_detection)) || anyDuplicated(names(parser_detection)) || any(!names(parser_detection) %in% resources$resource_id)) stop("Detection evidence must bind known resources")
    for (rid in names(parser_detection)) {
      expected_hash <- resources$sha256[resources$resource_id == rid]
      actual_hash <- parser_detection[[rid]]$resource_sha256
      if (!is.character(actual_hash) || length(actual_hash) != 1L || is.na(actual_hash) || actual_hash != expected_hash) stop("Detection evidence does not match resource bytes")
    }
  }
  if (!is.list(schema) || !setequal(names(schema), c("profile_id", "confirmed", "evidence")) || anyDuplicated(names(schema))) stop("Invalid schema declaration")
  scalar_text(schema$profile_id, "profile_id")
  scalar_text(schema$evidence, "evidence", empty = TRUE)
  if (!is.logical(schema$confirmed) || length(schema$confirmed) != 1L || is.na(schema$confirmed)) stop("confirmed must be TRUE or FALSE")
  if (!schema$profile_id %in% names(profile_catalogue()$profiles)) stop("Profile is not supported")
  if (schema$confirmed) scalar_text(schema$evidence, "confirmation evidence")
  if (!is.null(expected_revision)) expected_revision <- integer_bound(expected_revision, "expected_revision", .Machine$integer.max)
  payload <- list(parsers = parsers, metadata = metadata, schema = schema, parser_detection = parser_detection,
    profile_catalogue_version = profile_catalogue()$catalogue_version,
    parser_engine_version = "lexical-preview-1.0")
  text <- json_text(payload)
  id <- new_id(repo, "config")
  with_write(repo$con, function() {
    assert_workspace_active(repo, version_id, membership)
    old <- DBI::dbGetQuery(repo$con, "SELECT config_id, revision FROM configuration_revisions WHERE version_id = ? ORDER BY revision DESC LIMIT 1", params = list(version_id))
    actual <- if (nrow(old)) old$revision else 0L
    expected <- if (is.null(expected_revision)) 0L else expected_revision
    if (actual != expected) stop("stale configuration revision; reload before saving", call. = FALSE)
    DBI::dbExecute(repo$con, "INSERT INTO configuration_revisions VALUES (?, ?, ?, ?, ?, ?, ?, ?)", params = list(id, version_id, actual + 1L,
      if (nrow(old)) old$config_id else NA_character_, text, hash_text(text), actor_id, utc_now()))
  })
  get_configuration(repo, id)
}

#' Retrieve a frozen configuration snapshot
#' @param repo Open repository handle.
#' @param config_id Exact configuration revision ID.
#' @return Named list with identifiers, provenance and decoded snapshot fields.
#' @export
get_configuration <- function(repo, config_id) {
  row <- one_row(repo, "configuration_revisions", "config_id", config_id)
  if (hash_text(row$payload_json) != row$context_hash) stop("Configuration integrity mismatch")
  c(as.list(row[, setdiff(names(row), "payload_json"), drop = FALSE]), decode_json(row$payload_json))
}

#' List a source version's configuration revisions
#' @param repo Open repository handle.
#' @param version_id Source version ID.
#' @return Data frame ordered by revision, retaining parent/actor/time references.
#' @export
list_configurations <- function(repo, version_id) {
  one_row(repo, "dataset_versions", "version_id", version_id)
  DBI::dbGetQuery(repo$con, "SELECT config_id, version_id, revision, parent_config_id, context_hash, actor_id, created_at FROM configuration_revisions WHERE version_id = ? ORDER BY revision", params = list(version_id))
}
