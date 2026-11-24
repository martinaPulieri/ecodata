# Reproducible manual acceptance script. Run from ecoplatform-r/:
# Rscript --vanilla tools/manual-step1.R
# It creates a fresh local runtime (never overwrites an existing one), prints
# evidence, closes/reopens SQLite and writes portable manifests for inspection.
extra_library <- Sys.getenv("ECODATA_R_LIBRARY")
if (nzchar(extra_library)) .libPaths(c(extra_library, .libPaths()))
if (!nzchar(extra_library) && requireNamespace("renv", quietly = TRUE)) {
  restored_library <- renv::paths$library(project = getwd())
  if (dir.exists(restored_library)) .libPaths(c(restored_library, .libPaths()))
}
pkgload::load_all(".", quiet = TRUE)
root <- Sys.getenv("ECODATA_MANUAL_ROOT", unset = file.path(tools::R_user_dir("ecodata", "data"), paste0("manual-step1-", format(Sys.time(), "%Y%m%d-%H%M%S"))))
if (dir.exists(root)) stop("Choose a new ECODATA_MANUAL_ROOT; this script does not reuse or overwrite runtimes")
repo <- open_repository(root)
tryCatch({
  source <- file.path(repo$root, "tmp", "synthetic.csv")
  writeBin(charToRaw("station;value;date\n001;1,5;03/04/25\n002;0;NA\n"), source)
  input_hash <- digest::digest(file = source, algo = "sha256", serialize = FALSE)
  registered <- register_input(source, list(title = "Manual synthetic ecological input",
    source = "synthetic", licence = "CC0", date_convention = "unknown"), repo)
  resources <- get_input(repo, registered$version_id)$resources
  first <- save_configuration(repo, registered$version_id, actor_id = "manual-reviewer")
  parsers <- first$parsers
  parsers[[resources$resource_id]]$delimiter <- ";"
  parsers[[resources$resource_id]]$decimal_mark <- ","
  second <- save_configuration(repo, registered$version_id, parsers = parsers,
    metadata = list(date_convention = "unknown"), expected_revision = 1L, actor_id = "manual-reviewer")
  inspection <- inspect_input(registered$version_id, second$config_id, repo)
  table <- inspection$resources[[1]]$tables[[1]]
  stopifnot(identical(table$preview[[1]], c("001", "002")),
    identical(table$preview[[2]], c("1,5", "0")),
    identical(table$preview[[3]], c("03/04/25", "NA")),
    get_configuration(repo, first$config_id)$parsers[[resources$resource_id]]$delimiter == ",")
  cat("PASS: lexical values preserved; date remains unparsed and ambiguous.\n")
  print(table$preview)
  op <- submit_operation(repo, registered$version_id, second$config_id, "inspect", "manual-inspection-1", "manual-reviewer")
  duplicate <- submit_operation(repo, registered$version_id, second$config_id, "inspect", "manual-inspection-1", "manual-reviewer")
  stopifnot(identical(op$operation_id, duplicate$operation_id))
  record_operation_event(repo, op$operation_id, "running", "manual-reviewer")
  record_operation_event(repo, op$operation_id, "completed", "manual-reviewer", "Bounded lexical inspection verified in this script")
  cat("PASS: duplicate submission reused one operation; three lifecycle events retained.\n")
  stale <- tryCatch(save_configuration(repo, registered$version_id, expected_revision = 1L, actor_id = "manual-reviewer"), error = conditionMessage)
  stopifnot(is.character(stale), grepl("stale", stale))
  cat("PASS: stale configuration update rejected.\n")
  stopifnot(input_hash == digest::digest(file = source, algo = "sha256", serialize = FALSE))
  backup <- file.path(repo$root, "backups", "history-step1.sqlite")
  backup_repository(repo, backup)
  close_repository(repo)
  repo <- open_repository(root)
  stopifnot(verify_input(repo, registered$version_id)$ok,
    nrow(list_configurations(repo, registered$version_id)) == 2L,
    identical(get_operation(repo, op$operation_id)$events$status, c("queued", "running", "completed")))
  cat("PASS: restart recovered originals, both revisions and full history.\n")
  evidence <- list(runtime_root = repo$root, database_path = repo$db_path,
    dataset_id = registered$dataset_id, version_id = registered$version_id,
    configuration_ids = c(first$config_id, second$config_id), operation_id = op$operation_id,
    original_sha256 = input_hash, original_unchanged = TRUE,
    integrity_check = DBI::dbGetQuery(repo$con, "PRAGMA integrity_check")[[1]],
    foreign_key_violations = nrow(DBI::dbGetQuery(repo$con, "PRAGMA foreign_key_check")),
    schema_version = DBI::dbGetQuery(repo$con, "PRAGMA user_version")[[1]],
    scientific_checks_executed = FALSE)
  jsonlite::write_json(evidence, file.path(repo$root, "artefacts", "manual-evidence.json"), auto_unbox = TRUE, pretty = TRUE)
  utils::write.csv(list_configurations(repo, registered$version_id), file.path(repo$root, "artefacts", "configuration-history.csv"), row.names = FALSE)
  utils::write.csv(get_operation(repo, op$operation_id)$events, file.path(repo$root, "artefacts", "operation-events.csv"), row.names = FALSE)
  print(evidence)
  cat("PASS: consistent SQLite snapshot and portable inspection evidence written.\n")
}, finally = close_repository(repo))
