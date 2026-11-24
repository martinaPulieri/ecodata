# Acceptance with the real Venezia bytes; original data are never rewritten.
# Run from ecoplatform-r/. Optionally choose a NEW local runtime with
# ECODATA_REMOVAL_ROOT and the external CSV with ECODATA_VENEZIA_FILE.
extra_library <- Sys.getenv("ECODATA_R_LIBRARY")
if (nzchar(extra_library)) .libPaths(c(extra_library, .libPaths()))
pkgload::load_all(".", quiet = TRUE)
root <- Sys.getenv("ECODATA_REMOVAL_ROOT", unset = tempfile("ecodata-removal-"))
if (dir.exists(root)) stop("Choose a new acceptance runtime; existing data will not be changed")
path <- Sys.getenv("ECODATA_VENEZIA_FILE", unset = file.path("..", "..", "..", "data_examples", "VE_12_ACTRMO0038_Dati macrozoobenthos Venezia 2011.csv"))
path <- normalizePath(path, winslash = "/", mustWork = TRUE)
hash <- digest::digest(file = path, algo = "sha256", serialize = FALSE)
repo <- open_repository(root)
tryCatch({
  upload <- data.frame(name = basename(path), size = file.info(path)$size, type = "text/csv", datapath = path)
  v <- register_uploaded_inputs(repo, upload, "Venezia 2011", "acceptance")
  sibling <- register_input(path, list(title = "Venezia - independent source version"), repo, parent_version_id = v$version_id)
  save_configuration(repo, sibling$version_id, actor_id = "acceptance")
  preview <- run_workspace_inspection(repo, v$version_id, v$config_id, "acceptance")
  resources <- get_input(repo, v$version_id)$resources
  table <- preview$inspection$resources[[1]]$tables[[1]]$preview
  configs <- list_configurations(repo, v$version_id)
  operations <- list_operations(repo)
  set_workspace_state(repo, v$version_id, "removed", 0L, "acceptance-remove", "acceptance")
  stopifnot(!v$version_id %in% list_workspace_inputs(repo)$version_id,
    sibling$version_id %in% list_workspace_inputs(repo)$version_id,
    identical(list_configurations(repo, v$version_id), configs), identical(list_operations(repo), operations),
    verify_input(repo, v$version_id)$ok)
  close_repository(repo)
  repo <- open_repository(root)
  stopifnot(get_workspace_state(repo, v$version_id)$state == "removed")
  set_workspace_state(repo, v$version_id, "active", 1L, "acceptance-restore", "acceptance")
  rerun <- run_workspace_inspection(repo, v$version_id, v$config_id, "acceptance")
  stopifnot(identical(rerun$inspection$resources[[1]]$tables[[1]]$preview, table),
    verify_input(repo, v$version_id)$ok, identical(resources, get_input(repo, v$version_id)$resources),
    identical(hash, digest::digest(file = path, algo = "sha256", serialize = FALSE)))
  result <- list(runtime = repo$root, version_id = v$version_id, original_sha256 = hash,
    preview_rows = nrow(table), preview_columns = ncol(table),
    lifecycle = list_workspace_events(repo, v$version_id)$state,
    sibling_unchanged = TRUE, originals_unchanged = TRUE, history_retained = TRUE,
    restart_preserved_removal = TRUE, restored_preview_identical = TRUE)
  dir.create("evidence/removal", recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(result, "evidence/removal/venezia-result.json", pretty = TRUE, auto_unbox = TRUE)
  print(result)
}, finally = close_repository(repo))
