# Optional smoke check of user-provided examples; never imports data into Git.
# Set ECODATA_EXAMPLES_DIR to the local directory containing the approved files.
# Parser overrides below are explicit technical choices, not scientific mappings.
extra_library <- Sys.getenv("ECODATA_R_LIBRARY")
if (nzchar(extra_library)) .libPaths(c(extra_library, .libPaths()))
if (!nzchar(extra_library) && requireNamespace("renv", quietly = TRUE)) {
  restored_library <- renv::paths$library(project = getwd())
  if (dir.exists(restored_library)) .libPaths(c(restored_library, .libPaths()))
}
pkgload::load_all(".", quiet = TRUE)
examples <- Sys.getenv("ECODATA_EXAMPLES_DIR")
if (!nzchar(examples) || !dir.exists(examples)) stop("Set ECODATA_EXAMPLES_DIR to the original examples directory")
repo <- open_repository(tempfile("ecodata-examples-"))
tryCatch({
  for (path in list.files(examples, full.names = TRUE)) {
    registered <- register_input(path, list(source = "User-provided example; scientific meanings not inferred"), repo)
    resources <- get_input(repo, registered$version_id)$resources
    parsers <- stats::setNames(lapply(resources$original_name, function(name) list(delimiter = ",", encoding = "UTF-8", decimal_mark = ".", quote = '"')), resources$resource_id)
    if (basename(path) == "sonda_transizione_2010.csv") parsers[[1]]$encoding <- "windows-1252"
    if (basename(path) == "VE_12_ACTRMO0038_Dati macrozoobenthos Venezia 2011.csv") {
      parsers[[1]]$encoding <- "UTF-16LE"
      parsers[[1]]$delimiter <- "\t"
    }
    config <- save_configuration(repo, registered$version_id, parsers = parsers, actor_id = "example-smoke-check")
    inspection <- inspect_input(registered$version_id, config$config_id, repo)$resources[[1]]
    intact <- verify_input(repo, registered$version_id)$ok
    stopifnot(intact)
    cat(basename(path), "|", resources$size_bytes, "bytes |", inspection$status, "|", length(inspection$tables), "tables | integrity:", intact, "|", inspection$diagnostic, "\n")
  }
}, finally = close_repository(repo))
