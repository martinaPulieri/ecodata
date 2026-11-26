# Task 2D synthetic acceptance. Run from ecoplatform-r/ with ECODATA_R_LIBRARY.
# Creates a fresh temporary runtime; never opens the user's review database.
.libPaths(c(Sys.getenv("ECODATA_R_LIBRARY"), .libPaths()))
pkgload::load_all(".", quiet = TRUE)
runtime <- Sys.getenv("ECODATA_DATES_ROOT", unset = tempfile("ecodata-dates-"))
if (dir.exists(runtime)) stop("Choose a new isolated runtime")
repo <- open_repository(runtime)
source <- tempfile(fileext = ".csv")
writeLines(c("id,sample,anno,giorno,mese",
  "1,2020-03-15,2020,7,03", "2,2020-02-30,2020,07,",
  "3,03/04/2020,,,", "4,2020,2020,007,03",
  "5,2020-03,2020,99,99", "6,2020-03-15T14:30:00Z,2020,7,03",
  "7,2020-03-15/2020-03-20,2020,7,03", "8,,2020,7,03",
  "9,spring 2020,2020,7,03"), source, useBytes = TRUE)
source_hash <- hash_file(source)
v <- register_input(source, list(title = "Synthetic lexical date acceptance"), repo)
table <- new_validation_table(v$version_id, v$resource_ids[1], c("id", "sample", "anno", "giorno", "mese"))
single <- new_date_mapping(table, "sampling", "sampling_date", c(value = 1), "user",
  "acceptance-synthetic", "Synthetic field role", TRUE)
split <- new_date_mapping(table, "analysis", "analysis_date", c(year = 2, day = 3, month = 4), "user",
  "acceptance-synthetic", "Synthetic named component roles", TRUE)
cfg <- save_configuration(repo, v$version_id, actor_id = "acceptance-synthetic",
  validation_spec = new_validation_spec(list(single, split), pattern_version = "date-patterns-1.0"))
configs <- list_configurations(repo, v$version_id)
result <- run_date_validation(repo, v$version_id, cfg$config_id)
a <- result$mappings[[1]]; b <- result$mappings[[2]]
stopifnot(result$status == "completed", length(a$rows) == 9L, length(b$rows) == 9L,
  a$summary$counts$recognised == 6L, a$summary$counts$ambiguous == 1L,
  a$summary$counts$missing == 1L, a$summary$counts$unrecognised == 1L,
  b$summary$counts$recognised == 6L, b$summary$counts$incomplete == 1L,
  b$summary$counts$missing == 1L, b$summary$counts$unrecognised == 1L,
  identical(b$rows[[1]]$original_values, list(day = "7", month = "03", year = "2020")),
  all(unlist(b$rows[[1]]$observed_widths) == c(day = 1, month = 2, year = 4)),
  !result$calendar_validation, !result$value_conversion,
  identical(list_configurations(repo, v$version_id), configs), nrow(list_operations(repo)) == 0L,
  verify_input(repo, v$version_id)$ok, identical(hash_file(source), source_hash))
close_repository(repo)
repo <- open_repository(runtime)
stopifnot(identical(run_date_validation(repo, v$version_id, cfg$config_id), result),
  identical(list_configurations(repo, v$version_id), configs), nrow(list_operations(repo)) == 0L)
close_repository(repo)
dir.create("evidence/dates", recursive = TRUE, showWarnings = FALSE)
# Ignored acceptance artefacts; the app does not persist validation results yet.
writeLines(json_text(result), "evidence/dates/synthetic-result.json", useBytes = TRUE)
jsonlite::write_json(list(runtime = runtime, single_counts = a$summary$counts,
  split_counts = b$summary$counts, row_records = 18L, restart_identical = TRUE,
  source_hash_unchanged = TRUE, configurations_added_by_engine = 0L, operations_created = 0L),
  "evidence/dates/manual-result.json", pretty = TRUE, auto_unbox = TRUE)
cat("Single field: 9 rows -> recognised 6, ambiguous 1, missing 1, unrecognised 1.\n")
cat("Split group: 9 rows -> recognised 6, incomplete 1, missing 1, unrecognised 1.\n")
cat("18 typed records; source/configuration unchanged; identical after restart; no operations saved.\n")
cat("Runtime:", runtime, "\n")
