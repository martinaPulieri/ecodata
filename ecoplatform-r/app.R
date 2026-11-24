# Run this directory with shiny::runApp(), or use tools/launch-shiny.R.
extra_library <- Sys.getenv("ECODATA_R_LIBRARY")
if (nzchar(extra_library)) .libPaths(c(extra_library, .libPaths()))
pkgload::load_all(".", quiet = TRUE)
options(shiny.maxRequestSize = 201 * 1024^2)
runtime_root <- Sys.getenv("ECODATA_RUNTIME_ROOT")
run_app(if (nzchar(runtime_root)) runtime_root else NULL)
