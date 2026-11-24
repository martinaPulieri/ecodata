# Real-dataset acceptance, run from ecoplatform-r/; does not modify the dataset
# or include its records in Git. ECODATA_VENEZIA_FILE may override its location.
extra_library <- Sys.getenv("ECODATA_R_LIBRARY")
if (nzchar(extra_library)) .libPaths(c(extra_library, .libPaths()))
if (!nzchar(extra_library) && requireNamespace("renv", quietly = TRUE)) {
  restored <- renv::paths$library(project = getwd())
  if (dir.exists(restored)) .libPaths(c(restored, .libPaths()))
}
pkgload::load_all(".", quiet = TRUE)
path <- Sys.getenv("ECODATA_VENEZIA_FILE", unset = file.path("..", "..", "..", "data_examples", "VE_12_ACTRMO0038_Dati macrozoobenthos Venezia 2011.csv"))
path <- normalizePath(path, winslash = "/", mustWork = TRUE)
before <- digest::digest(file = path, algo = "sha256", serialize = FALSE)
repo <- open_repository(tempfile("venezia-autodetection-"))
tryCatch({
  upload <- data.frame(name = basename(path), size = file.info(path)$size, type = "text/csv", datapath = path)
  registered <- register_uploaded_inputs(repo, upload, "Venezia automatic detection acceptance", "acceptance")
  resource <- get_input(repo, registered$version_id)$resources
  cfg <- get_configuration(repo, registered$config_id)
  parser <- cfg$parsers[[resource$resource_id]]
  evidence <- cfg$parser_detection[[resource$resource_id]]
  stopifnot(cfg$revision == 1L, parser$encoding == "UTF-16LE", parser$delimiter == "\t",
    evidence$status == "detected", evidence$encoding$method == "bom")
  preview <- run_workspace_inspection(repo, registered$version_id, cfg$config_id, "acceptance")$inspection$resources[[1]]
  stopifnot(preview$status == "ready", nrow(preview$tables[[1]]$preview) == 20L,
    ncol(preview$tables[[1]]$preview) == 235L, verify_input(repo, registered$version_id)$ok)
  # Simulate an already registered pre-detection source without mutating history.
  legacy <- register_input(path, list(title = "Legacy parser defaults"), repo)
  old <- save_configuration(repo, legacy$version_id, actor_id = "acceptance")
  rid <- get_input(repo, legacy$version_id)$resources$resource_id
  fixed <- redetect_configuration(repo, old$config_id, rid, "acceptance")
  stopifnot(fixed$revision == 2L, fixed$parsers[[rid]]$encoding == "UTF-16LE",
    fixed$parsers[[rid]]$delimiter == "\t", get_configuration(repo, old$config_id)$parsers[[rid]]$encoding == "UTF-8",
    inspect_input(legacy$version_id, fixed$config_id, repo)$resources[[1]]$status == "ready")
  after <- digest::digest(file = path, algo = "sha256", serialize = FALSE)
  stopifnot(identical(before, after))
  result <- list(filename = basename(path), encoding = parser$encoding, separator = "tab",
    initial_revision = cfg$revision, detection_method = evidence$encoding$method,
    sample_bytes = evidence$sample_bytes, sample_truncated = evidence$sample_truncated,
    preview_rows = nrow(preview$tables[[1]]$preview), columns = ncol(preview$tables[[1]]$preview),
    no_manual_parser_settings = TRUE, original_sha256 = before, original_unchanged = TRUE,
    old_snapshot_preserved = TRUE, redetected_legacy_revision = fixed$revision)
  dir.create("evidence/autodetection", recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(result, "evidence/autodetection/venezia-result.json", auto_unbox = TRUE, pretty = TRUE)
  print(result)
}, finally = close_repository(repo))
