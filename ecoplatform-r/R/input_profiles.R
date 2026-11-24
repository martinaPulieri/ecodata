#' Read the versioned prerequisite profile catalogue
#'
#' Profiles identify supported representations only. Scientific required-field
#' rules and thresholds are deliberately not activated in this first step.
#' @return Named list including catalogue version, profiles and result vocabulary.
#' @export
profile_catalogue <- function() {
  decode_json(paste(readLines(system.file("profiles", "foundation-1.0.json", package = "ecodata", mustWork = TRUE), warn = FALSE), collapse = "\n"))
}

default_parser <- function(name) list(
  delimiter = if (tolower(tools::file_ext(name)) == "tsv") "\t" else ",",
  encoding = "UTF-8", decimal_mark = ".", quote = '"'
)

validate_parser <- function(parser) {
  expected <- c("delimiter", "encoding", "decimal_mark", "quote")
  if (!is.list(parser) || !setequal(names(parser), expected) || anyDuplicated(names(parser))) stop("Parser requires delimiter, encoding, decimal_mark and quote")
  for (key in expected) scalar_text(parser[[key]], key, empty = key %in% c("quote", "delimiter"))
  if (!parser$delimiter %in% c(",", ";", "\t", "|")) stop("Unsupported delimiter")
  if (!parser$encoding %in% c("UTF-8", "latin1", "windows-1252", "UTF-16LE", "UTF-16BE")) stop("Unsupported encoding")
  if (!parser$decimal_mark %in% c(".", ",")) stop("Unsupported decimal_mark")
  if (!parser$quote %in% c('"', "")) stop("Unsupported quote")
  parser
}

#' Confirm a supported schema in a new configuration revision
#'
#' Confirmation records a user's declaration and evidence. It does not validate
#' the declaration or run scientific checks. Unsupported schemas remain generic.
#' @param version_id Source version ID.
#' @param profile_id Supported profile identifier from profile_catalogue().
#' @param evidence Nonempty explanation of the confirmation evidence.
#' @param expected_revision Exact current revision number.
#' @param repo Open repository handle.
#' @param actor_id Explicit user or worker identity.
#' @return New configuration snapshot.
#' @export
confirm_profile <- function(version_id, profile_id, evidence, expected_revision, repo, actor_id) {
  scalar_text(evidence, "evidence")
  if (!profile_id %in% names(profile_catalogue()$profiles)) stop("Profile is not supported")
  revisions <- list_configurations(repo, version_id)
  if (!nrow(revisions)) stop("Create an initial configuration before confirming a profile")
  latest <- get_configuration(repo, utils::tail(revisions$config_id, 1))
  save_configuration(repo, version_id, parsers = latest$parsers, metadata = latest$metadata,
    schema = list(profile_id = profile_id, confirmed = TRUE, evidence = evidence),
    parser_detection = if (is.null(latest$parser_detection)) list() else latest$parser_detection,
    expected_revision = expected_revision, actor_id = actor_id)
}
