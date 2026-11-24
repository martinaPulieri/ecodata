# Run from ecoplatform-r/: Rscript --vanilla tools/launch-shiny.R
extra_library <- Sys.getenv("ECODATA_R_LIBRARY")
if (nzchar(extra_library)) .libPaths(c(extra_library, .libPaths()))
if (!nzchar(extra_library) && requireNamespace("renv", quietly = TRUE)) {
  restored_library <- renv::paths$library(project = getwd())
  if (dir.exists(restored_library)) .libPaths(c(restored_library, .libPaths()))
}
pkgload::load_all(".", quiet = TRUE)
port <- suppressWarnings(as.integer(Sys.getenv("ECODATA_PORT", unset = "8791")))
if (is.na(port) || port < 1024L || port > 65535L) stop("Choose a valid ECODATA_PORT")
runtime <- Sys.getenv("ECODATA_RUNTIME_ROOT")
options(shiny.maxRequestSize = 201 * 1024^2)
shiny::runApp(run_app(if (nzchar(runtime)) runtime else NULL), host = "127.0.0.1", port = port, launch.browser = FALSE)
