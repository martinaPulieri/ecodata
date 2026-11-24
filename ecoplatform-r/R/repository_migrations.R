#' Apply an atomic repository schema migration
#'
#' Default use initialises schema v1 or leaves an existing v1 unchanged. Future
#' explicit upgrades back up the committed database before changing it. Schema
#' checks, SQL changes and user_version updates share one write reservation.
#' @param con Open SQLite connection.
#' @param statements Optional character vector of individual SQL statements for
#'   a controlled future migration. Not intended for end-user SQL execution.
#' @param target_version Positive integer schema version.
#' @return Current schema version, invisibly.
#' @export
migrate_repository <- function(con, statements = NULL, target_version = 1L) {
  target_version <- integer_bound(target_version, "target_version", 100000L)
  with_write(con, function() {
    # Another migrator may have committed while this writer was waiting.
    current <- DBI::dbGetQuery(con, "PRAGMA user_version")[[1]]
    if (current > target_version) stop("Database schema is newer than requested version")
    if (current == target_version) return(invisible(current))
    if (is.null(statements)) {
      if (current != 0L || target_version != 1L) stop("No migration is registered for this upgrade")
      if (length(DBI::dbListTables(con))) stop("Unrecognised unversioned database; no schema changes made")
      file <- system.file("sql", "001_validation.sql", package = "ecodata", mustWork = TRUE)
      statements <- strsplit(paste(readLines(file, warn = FALSE), collapse = "\n"), "\n-- statement\n", fixed = TRUE)[[1]]
      immutable <- c("datasets", "dataset_versions", "resources", "configuration_revisions", "operations", "operation_events")
      for (table in immutable) for (action in c("UPDATE", "DELETE")) {
        statements <- c(statements, sprintf("CREATE TRIGGER %s_%s_immutable BEFORE %s ON %s BEGIN SELECT RAISE(ABORT, 'immutable history'); END", table, tolower(action), action, table))
      }
    }
    if (!is.character(statements) || !length(statements) || anyNA(statements)) stop("statements must be nonempty SQL")
    if (current > 0L) {
      db_path <- DBI::dbGetInfo(con)$dbname
      backup_dir <- file.path(dirname(dirname(db_path)), "backups")
      dir.create(backup_dir, showWarnings = FALSE)
      # Read committed data through another connection while the RESERVED lock
      # prevents concurrent writers; do not back up from our write transaction.
      reader <- DBI::dbConnect(RSQLite::SQLite(), db_path, flags = RSQLite::SQLITE_RO)
      tryCatch(backup_repository(list(con = reader), tempfile(paste0("before-v", target_version, "-"), tmpdir = backup_dir, fileext = ".sqlite")),
        finally = DBI::dbDisconnect(reader))
    }
    for (statement in statements) DBI::dbExecute(con, statement)
    DBI::dbExecute(con, paste0("PRAGMA user_version = ", target_version))
  })
  invisible(target_version)
}
