#' Register immutable local input files
#'
#' Copies every source into owned storage and checks SHA-256 before committing
#' the manifest. Identical names/bytes still receive separate identities.
#' Failure rolls back the manifest and removes only this attempt's new copies.
#' An interruption may leave unreferenced copies; they are never auto-deleted.
#' Technical byte integrity does not establish upstream acquisition completeness.
#' @param paths Nonempty vector of existing regular local files.
#' @param metadata JSON-compatible list of supplied metadata; no interpretation.
#' @param repo Open repository handle.
#' @param parent_version_id Optional existing parent, for a new source delivery.
#' @param acquisition_status Complete/incomplete/unknown declaration, scalar or
#'   one per file. The default unknown is never promoted to complete by hashing.
#' @param max_file_bytes Maximum single-file size (default 50 MiB).
#' @param max_total_bytes Maximum total copy size (default 200 MiB).
#' @param original_names Optional original display filenames, one per path. Used
#'   for browser uploads whose temporary paths do not retain their original names.
#'   These names never determine an owned filesystem path.
#' @return List with dataset_id, version_id and resource_ids.
#' @export
register_input <- function(paths, metadata, repo, parent_version_id = NULL,
                           acquisition_status = "unknown", max_file_bytes = 50 * 1024^2,
                           max_total_bytes = 200 * 1024^2, original_names = NULL) {
  if (!is.character(paths) || !length(paths) || length(paths) > 100L || anyNA(paths)) stop("paths must contain 1-100 regular files")
  info <- file.info(paths)
  if (anyNA(info$size) || any(info$isdir) || any(!file.exists(paths))) stop("Every input must be an existing regular file")
  if (is.null(original_names)) original_names <- basename(paths)
  if (!is.character(original_names) || length(original_names) != length(paths) || anyNA(original_names) || any(!nzchar(trimws(original_names))) || any(grepl("[/\\\\:]", original_names)) || any(original_names %in% c(".", ".."))) stop("Invalid original filename")
  for (limit in list(max_file_bytes, max_total_bytes)) if (!is.numeric(limit) || length(limit) != 1L || !is.finite(limit) || limit < 1) stop("Size limits must be positive finite numbers")
  if (any(info$size > max_file_bytes) || sum(info$size) > max_total_bytes) stop("Input byte limit exceeded before copying")
  if (!is.list(metadata)) stop("metadata must be a list")
  metadata_json <- json_text(metadata)
  if (!length(acquisition_status) %in% c(1L, length(paths)) || anyNA(acquisition_status) || any(!acquisition_status %in% c("complete", "incomplete", "unknown"))) stop("Invalid acquisition_status")
  acquisition_status <- rep(acquisition_status, length.out = length(paths))
  dataset_id <- if (is.null(parent_version_id)) new_id(repo, "dataset") else one_row(repo, "dataset_versions", "version_id", parent_version_id)$dataset_id
  version_id <- new_id(repo, "version")
  version_dir <- file.path(repo$root, "inputs", version_id)
  if (!dir.create(version_dir, showWarnings = FALSE)) stop("Cannot reserve owned input directory")
  committed <- FALSE
  # version_dir is generated here, never derived from a user-supplied filename.
  on.exit(if (!committed) unlink(version_dir, recursive = TRUE))
  ids <- character(length(paths))
  manifest <- vector("list", length(paths))
  for (i in seq_along(paths)) {
    ids[i] <- new_id(repo, "resource")
    relative <- paste("inputs", version_id, ids[i], sep = "/")
    owned <- file.path(repo$root, relative)
    before <- hash_file(paths[i])
    if (!file.copy(paths[i], owned, overwrite = FALSE, copy.mode = FALSE)) stop("Cannot copy input")
    copied <- hash_file(owned)
    if (before != copied || before != hash_file(paths[i]) || file.info(owned)$size != info$size[i]) stop("Source changed during registration; integrity not verified")
    manifest[[i]] <- list(ids[i], version_id, i, original_names[i], relative, copied,
                          as.numeric(info$size[i]), acquisition_status[i], "verified")
  }
  with_write(repo$con, function() {
    now <- utc_now()
    if (is.null(parent_version_id)) DBI::dbExecute(repo$con, "INSERT INTO datasets VALUES (?, ?)", params = list(dataset_id, now))
    DBI::dbExecute(repo$con, "INSERT INTO dataset_versions VALUES (?, ?, ?, ?, ?)", params = list(version_id, dataset_id, if (is.null(parent_version_id)) NA_character_ else parent_version_id, metadata_json, now))
    for (row in manifest) DBI::dbExecute(repo$con, "INSERT INTO resources VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", params = row)
  })
  committed <- TRUE
  list(dataset_id = dataset_id, version_id = version_id, resource_ids = ids)
}

#' Retrieve a versioned input manifest
#' @param repo Open repository handle.
#' @param version_id Registered immutable dataset version ID.
#' @return List containing version row, supplied metadata and ordered resources.
#' @export
get_input <- function(repo, version_id) {
  version <- one_row(repo, "dataset_versions", "version_id", version_id)
  resources <- DBI::dbGetQuery(repo$con, "SELECT * FROM resources WHERE version_id = ? ORDER BY ordinal", params = list(version_id))
  # Resolve only our generated storage layout, never arbitrary manifest paths.
  if (any(!grepl("^inputs/version_[a-f0-9]{32}/resource_[a-f0-9]{32}$", resources$owned_relative_path))) stop("Unsafe resource path in manifest")
  resources$owned_path <- file.path(repo$root, resources$owned_relative_path)
  list(version = version, metadata = decode_json(version$metadata_json), resources = resources)
}

#' List registered source versions
#' @param repo Open repository handle.
#' @return Data frame of versions in creation order.
#' @export
list_inputs <- function(repo) DBI::dbGetQuery(repo$con, "SELECT version_id, dataset_id, parent_version_id, created_at FROM dataset_versions ORDER BY rowid")

#' Recheck managed input integrity
#' @param repo Open repository handle.
#' @param version_id Registered immutable dataset version ID.
#' @return List with overall ok and per-resource current integrity checks.
#' @export
verify_input <- function(repo, version_id) {
  resources <- get_input(repo, version_id)$resources
  resources$ok <- vapply(seq_len(nrow(resources)), function(i) {
    path <- resources$owned_path[i]
    tryCatch(file.exists(path) && !dir.exists(path) && file.info(path)$size == resources$size_bytes[i] && hash_file(path) == resources$sha256[i], error = function(e) FALSE)
  }, logical(1))
  list(ok = nrow(resources) > 0L && all(resources$ok), resources = resources)
}
