#' Open or close a local ecological processing repository
#'
#' Creates the managed runtime directories and opens SQLite with foreign keys,
#' WAL and a five-second busy timeout. Known Dropbox/OneDrive paths are rejected;
#' administrators must also exclude other synchronised or network filesystems.
#' Opening a repository never reclassifies another worker's pending operations.
#' @param runtime_root Local, non-synchronised runtime directory. Defaults to
#'   ECODATA_RUNTIME_ROOT or the user's application-data directory.
#' @param repo Repository handle returned by open_repository().
#' @return open_repository() returns a handle with root, con and db_path;
#'   close_repository() returns NULL invisibly and tolerates repeated closing.
#' @export
open_repository <- function(runtime_root = Sys.getenv("ECODATA_RUNTIME_ROOT", unset = file.path(tools::R_user_dir("ecodata", "data"), "runtime"))) {
  scalar_text(runtime_root, "runtime_root")
  # Reject UNC paths before normalizePath(), which may contact an unavailable
  # network share and on Windows can return backslashes for nonexistent paths.
  requested <- gsub("\\", "/", runtime_root, fixed = TRUE)
  if (grepl("^//", requested) || grepl("(^|/)(Dropbox|OneDrive[^/]*)(/|$)", requested, ignore.case = TRUE)) {
    stop("runtime_root must be on a local non-synchronised disk", call. = FALSE)
  }
  root <- normalizePath(runtime_root, winslash = "/", mustWork = FALSE)
  if (grepl("(^|/)(Dropbox|OneDrive[^/]*)(/|$)", root, ignore.case = TRUE) || grepl("^//", root)) {
    stop("runtime_root must be on a local non-synchronised disk", call. = FALSE)
  }
  for (part in c("database", "inputs", "artefacts", "reference-cache", "logs", "backups", "tmp")) {
    if (!dir.create(file.path(root, part), recursive = TRUE, showWarnings = FALSE) && !dir.exists(file.path(root, part))) stop("Cannot create runtime directory")
  }
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  path <- file.path(root, "database", "history.sqlite")
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  success <- FALSE
  on.exit(if (!success) DBI::dbDisconnect(con))
  DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
  DBI::dbExecute(con, "PRAGMA busy_timeout = 5000")
  # The migration rechecks version and table ownership under its write lock.
  version <- DBI::dbGetQuery(con, "PRAGMA user_version")[[1]]
  if (version > 2L) stop("Database schema is newer than this application")
  # SQLite's journal-mode negotiation may return BUSY immediately even with
  # busy_timeout when two processes first create/open the same database.
  deadline <- proc.time()[["elapsed"]] + 5
  repeat {
    mode <- tryCatch(DBI::dbGetQuery(con, "PRAGMA journal_mode = WAL"), error = identity)
    if (!inherits(mode, "error")) break
    if (!grepl("database is (locked|busy)", conditionMessage(mode)) || proc.time()[["elapsed"]] >= deadline) stop(mode)
    Sys.sleep(0.05)
  }
  repo <- structure(list(root = root, con = con, db_path = path), class = "ecodata_repository")
  migrate_repository(con)
  success <- TRUE
  repo
}

#' @rdname open_repository
#' @export
close_repository <- function(repo) {
  if (DBI::dbIsValid(repo$con)) DBI::dbDisconnect(repo$con)
  invisible(NULL)
}

#' Make a consistent SQLite snapshot
#'
#' Uses SQLite's backup API, including committed WAL content. The snapshot is a
#' database backup only: managed input files must be retained separately.
#' Publication requires hard-link support in the destination filesystem and is
#' exclusive; a failed copy never publishes a partial final destination.
#' @param repo Open repository handle.
#' @param destination New file path; existing destinations are never overwritten.
#' @return Normalised path to the database snapshot, invisibly.
#' @export
backup_repository <- function(repo, destination) {
  scalar_text(destination, "destination")
  if (!DBI::dbIsValid(repo$con)) stop("Cannot back up a closed repository")
  if (file.exists(destination)) stop("Backup destination already exists")
  if (!dir.exists(dirname(destination))) stop("Backup parent directory does not exist")
  # Reserve a sibling staging directory atomically; publish only a closed,
  # verified snapshot. Hard-link creation cannot overwrite a concurrent file.
  reservation <- paste0(destination, ".lock")
  if (!dir.create(reservation, showWarnings = FALSE)) stop("Backup destination is already reserved")
  out <- NULL
  on.exit({
    if (!is.null(out) && DBI::dbIsValid(out)) DBI::dbDisconnect(out)
    unlink(reservation, recursive = TRUE)
  }, add = TRUE)
  staged <- file.path(reservation, "snapshot.sqlite")
  out <- DBI::dbConnect(RSQLite::SQLite(), staged)
  RSQLite::sqliteCopyDatabase(repo$con, out)
  check <- DBI::dbGetQuery(out, "PRAGMA integrity_check")[[1]]
  if (!identical(check, "ok")) stop("Backup integrity check failed")
  DBI::dbDisconnect(out)
  if (!suppressWarnings(file.link(staged, destination))) stop("Cannot publish backup exclusively; destination exists or filesystem lacks hard links")
  invisible(normalizePath(destination, winslash = "/", mustWork = TRUE))
}
