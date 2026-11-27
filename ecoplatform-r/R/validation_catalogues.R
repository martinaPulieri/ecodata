#' Read pinned validation definitions
#'
#' These catalogues describe checks and patterns; reading them executes none.
#' Existing versions are retained when a new catalogue is introduced.
#' @param version Exact installed catalogue version. Unknown versions fail closed.
#' @return Plain JSON-compatible list, independent of Shiny and SQLite.
#' @export
validation_rules <- function(version = "linkage-dates-1.0") {
  read_validation_catalogue(version, "linkage-dates-1.0")
}

#' @rdname validation_rules
#' @export
date_patterns <- function(version = "date-patterns-0.1") {
  read_validation_catalogue(version, c("date-patterns-0.1", "date-patterns-1.0", "date-patterns-1.1", "date-patterns-1.2"))
}

read_validation_catalogue <- function(version, supported) {
  scalar_text(version, "catalogue version")
  if (!version %in% supported) stop("Unsupported catalogue version")
  path <- system.file("rules", paste0(version, ".json"), package = "ecodata", mustWork = TRUE)
  result <- decode_json(paste(readLines(path, warn = FALSE), collapse = "\n"))
  if (!identical(result$catalogue_version, version)) stop("Catalogue version mismatch")
  result
}

contract_copy <- function(x) decode_json(json_text(x))
catalogue_snapshot <- function(x) list(version = x$catalogue_version, sha256 = hash_text(json_text(x)), snapshot = x)
contract_equal <- function(x, y) identical(json_text(x), json_text(y))

contract_texts <- function(x, name, empty = FALSE) {
  if (!is.character(x) || anyNA(x) || (!empty && (!length(x) || any(!nzchar(x))))) stop("Invalid ", name)
  x
}

contract_count <- function(x, name) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) || x < 0 || x != floor(x) || x > .Machine$integer.max) stop("Invalid ", name)
  x
}

# External state labels must be explicit scalars; match.arg(NULL, ...) would
# invent the first state, and partial matching would conceal malformed input.
contract_enum <- function(value, choices, name) {
  scalar_text(value, name)
  if (!value %in% choices) stop("Invalid ", name)
  value
}

contract_fields <- function(value, fields, name) {
  if (!is.list(value) || is.null(names(value)) || anyDuplicated(names(value)) ||
      !setequal(names(value), fields)) stop("Invalid ", name, " fields")
  invisible(value)
}
