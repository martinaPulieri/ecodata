# Reproducible package build/check; use a local temporary staging directory.
# Run from ecoplatform-r/: Rscript --vanilla tools/check-step1.R
extra_library <- Sys.getenv("ECODATA_R_LIBRARY")
if (nzchar(extra_library)) .libPaths(c(extra_library, .libPaths()))
if (!nzchar(extra_library) && requireNamespace("renv", quietly = TRUE)) {
  restored_library <- renv::paths$library(project = getwd())
  if (dir.exists(restored_library)) .libPaths(c(restored_library, .libPaths()))
}
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
evidence <- Sys.getenv("ECODATA_CHECK_EVIDENCE", unset = file.path(root, "evidence", "step1"))
dir.create(evidence, recursive = TRUE, showWarnings = FALSE)
stage <- tempfile("ecodata-check-")
dir.create(stage)
# R CMD build copies before applying .Rbuildignore. On Windows a live log in
# evidence/ cannot be copied, so stage only package inputs before starting it.
source_dir <- file.path(stage, "source", "ecodata")
dir.create(source_dir, recursive = TRUE)
entries <- list.files(root, full.names = TRUE, all.files = TRUE, no.. = TRUE)
entries <- entries[!basename(entries) %in% c("evidence", "docs", "tools", "renv", "renv.lock")]
if (!all(file.copy(entries, source_dir, recursive = TRUE, copy.date = TRUE))) stop("Cannot stage package source")
Sys.setenv(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep),
           R_LIBS_USER = paste(.libPaths(), collapse = .Platform$path.sep),
           LANG = "en_US.UTF-8", LC_ALL = "English_United States.utf8")
setwd(stage)
rcmd <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rcmd.exe" else "R")
command_prefix <- if (.Platform$OS.type == "windows") character() else "CMD"
build_log <- file.path(evidence, "build.txt")
status <- system2(rcmd, c(command_prefix, "build", shQuote(source_dir)), stdout = build_log, stderr = build_log)
if (status != 0L) stop("Build failed; inspect ", build_log)
archive <- list.files(stage, "^ecodata_.*[.]tar[.]gz$", full.names = TRUE)
if (length(archive) != 1L) stop("Expected one built archive")
check_log <- file.path(evidence, "check-console.txt")
status <- system2(rcmd, c(command_prefix, "check", "--no-manual", shQuote(archive)), stdout = check_log, stderr = check_log)
summary <- file.path(stage, "ecodata.Rcheck", "00check.log")
if (file.exists(summary)) file.copy(summary, file.path(evidence, "package-check.txt"), overwrite = TRUE)
cat("Staging directory:", stage, "\n")
cat(readLines(file.path(evidence, "package-check.txt"), warn = FALSE), sep = "\n")
if (status != 0L) stop("Package check failed")
status_line <- grep("^Status:", readLines(file.path(evidence, "package-check.txt"), warn = FALSE), value = TRUE)
if (length(status_line) != 1L || trimws(status_line) != "Status: OK") stop("Package check reported warnings or notes; inspect package-check.txt")
