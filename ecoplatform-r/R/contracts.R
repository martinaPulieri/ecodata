# Internal contracts shared by repositories; no Shiny or scientific inference.
scalar_text <- function(x, name, empty = FALSE) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || (!empty && !nzchar(trimws(x)))) {
    stop(name, " must be a single ", if (!empty) "nonempty ", "string", call. = FALSE)
  }
  x
}

json_text <- function(x) {
  # Canonical key order makes fingerprints independent of R list construction order.
  canonical <- function(y) {
    if (is.list(y)) {
      if (!is.null(names(y))) {
        if (anyNA(names(y)) || any(!nzchar(names(y))) || anyDuplicated(names(y))) stop("JSON keys must be unique and nonempty")
        y <- y[order(names(y), method = "radix")]
      }
      y <- lapply(y, canonical)
    }
    if (is.function(y) || is.environment(y) || is.object(y)) stop("Metadata must contain plain JSON-compatible values")
    y
  }
  as.character(jsonlite::toJSON(canonical(x), auto_unbox = TRUE, null = "null", na = "null", digits = NA))
}

decode_json <- function(x) jsonlite::fromJSON(x, simplifyVector = FALSE)
utc_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
new_id <- function(repo, prefix) paste0(prefix, "_", DBI::dbGetQuery(repo$con, "SELECT lower(hex(randomblob(16))) AS id")$id)
hash_file <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
hash_text <- function(text) digest::digest(text, algo = "sha256", serialize = FALSE)

# BEGIN IMMEDIATE serialises read-then-append operations across connections.
# A stale revision is detected while holding the write reservation, not before it.
with_write <- function(con, fn) {
  DBI::dbExecute(con, "BEGIN IMMEDIATE")
  committed <- FALSE
  on.exit(if (!committed) try(DBI::dbRollback(con), silent = TRUE))
  result <- fn()
  DBI::dbCommit(con)
  committed <- TRUE
  result
}

one_row <- function(repo, table, column, id) {
  # Identifiers are private constants; user-provided values are always bound.
  result <- DBI::dbGetQuery(repo$con, paste0("SELECT * FROM ", table, " WHERE ", column, " = ?"), params = list(scalar_text(id, column)))
  if (nrow(result) != 1L) stop("Unknown ", column, call. = FALSE)
  result
}

integer_bound <- function(x, name, maximum) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) || x < 1 || x > maximum || x != floor(x)) stop(name, " must be a positive bounded integer")
  as.integer(x)
}
