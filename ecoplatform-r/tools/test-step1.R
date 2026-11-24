# Run from ecoplatform-r/: Rscript --vanilla tools/test-step1.R
# An optional ECODATA_R_LIBRARY points to an existing development library.
extra_library <- Sys.getenv("ECODATA_R_LIBRARY")
if (nzchar(extra_library)) .libPaths(c(extra_library, .libPaths()))
if (!nzchar(extra_library) && requireNamespace("renv", quietly = TRUE)) {
  restored_library <- renv::paths$library(project = getwd())
  if (dir.exists(restored_library)) .libPaths(c(restored_library, .libPaths()))
}
if (dir.exists("R")) pkgload::load_all(".", quiet = TRUE)
results <- testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = FALSE)
counts <- colSums(as.data.frame(results)[, c("passed", "failed", "error", "warning", "skipped")])
print(counts)
if (sum(counts[c("failed", "error", "warning")]) > 0) quit(status = 1)
