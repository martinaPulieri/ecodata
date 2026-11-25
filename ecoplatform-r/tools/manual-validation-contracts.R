# Task 2A demonstration, not a validator: classification/outcome inputs below
# are hand-specified synthetic examples. No date matcher or linkage scan runs.
# From ecoplatform-r/: Rscript --vanilla tools/manual-validation-contracts.R
extra_library <- Sys.getenv("ECODATA_R_LIBRARY")
if (nzchar(extra_library)) .libPaths(c(extra_library, .libPaths()))
pkgload::load_all(".", quiet = TRUE)
root <- Sys.getenv("ECODATA_CONTRACTS_ROOT", unset = tempfile("ecodata-contracts-"))
if (dir.exists(root)) stop("Choose a new runtime; this demonstration never reuses existing data")
stage <- tempfile("contracts-fixtures-"); dir.create(stage)
writeBin(charToRaw("anno,giorno,mese,data_analisi\n2020,7,03,03/04/2020\n2020,7,,2020-02-30\n,,,2020\n"), file.path(stage, "dates.csv"))
writeBin(charToRaw("id,occurrenceID\n001,obs1\n002,obs2\n002,obs3\n,obs4\n"), file.path(stage, "core.csv"))
writeBin(charToRaw("coreid,measurementValue\n001,1\n001,2\n002,3\n003,4\n,5\n"), file.path(stage, "measurements.csv"))
writeLines(c('<archive xmlns="http://rs.tdwg.org/dwc/text/">',
  '<core rowType="http://rs.tdwg.org/dwc/terms/Occurrence" encoding="UTF-8" fieldsTerminatedBy="," ignoreHeaderLines="1"><files><location>core.csv</location></files><id index="0"/><field index="1" term="http://rs.tdwg.org/dwc/terms/occurrenceID"/></core>',
  '<extension rowType="http://rs.tdwg.org/dwc/terms/MeasurementOrFact" encoding="UTF-8" fieldsTerminatedBy="," ignoreHeaderLines="1"><files><location>measurements.csv</location></files><coreid index="0"/></extension>',
  '</archive>'), file.path(stage, "meta.xml"))
archive <- file.path(stage, "synthetic.zip")
zip::zipr(archive, c("meta.xml", "core.csv", "measurements.csv"), root = stage)
paths <- c(file.path(stage, "dates.csv"), archive)
hashes <- vapply(paths, digest::digest, character(1), file = TRUE, algo = "sha256", serialize = FALSE)
repo <- open_repository(root)
tryCatch({
  input <- register_input(paths, list(title = "Contract demonstration only"), repo)
  date_table <- new_validation_table(input$version_id, input$resource_ids[1], c("anno", "giorno", "mese", "data_analisi"))
  sampling <- new_date_mapping(date_table, "sampling", "sampling_date", c(year = 0, day = 1, month = 2), "user", "manual-check", "Synthetic declared roles", TRUE)
  analysis <- new_date_mapping(date_table, "analysis", "analysis_date", c(value = 3), "user", "manual-check", "Synthetic analysis date role", TRUE)
  core <- new_validation_table(input$version_id, input$resource_ids[2], c("id", "occurrenceID"), "core.csv")
  extension <- new_validation_table(input$version_id, input$resource_ids[2], c("coreid", "measurementValue"), "measurements.csv")
  linkage <- new_linkage_mapping(core, 0, extension, 0, "relationship", "manual-check", "Synthetic meta.xml id/coreid index=0", TRUE)
  spec <- new_validation_spec(list(sampling, analysis), list(linkage))
  config <- save_configuration(repo, input$version_id, actor_id = "manual-check", validation_spec = spec)
  context <- freeze_validation_context(repo, config$config_id)
  dates <- list(
    new_date_result(context, "sampling", 1, c(year = "2020", day = "7", month = "03"), "recognised", "split-numeric"),
    new_date_result(context, "sampling", 2, c(year = "2020", day = "7", month = ""), "incomplete"),
    new_date_result(context, "sampling", 3, c(year = "", day = "", month = ""), "missing"))
  analysis_row <- new_date_result(context, "analysis", 1, c(value = "03/04/2020"), "ambiguous", c("dmy-slash", "mdy-slash"))
  references <- c("001", "001", "002", "003", "")
  outcomes <- c("linked", "linked", "ambiguous", "unresolved_reference", "missing_reference")
  targets <- list(1, 1, c(2, 3), numeric(), numeric())
  links <- lapply(1:5, function(i) new_linkage_result(context, "relationship", i, references[[i]], outcomes[[i]], targets[[i]]))
  date_summary <- summarise_date_results(context, "sampling", dates, 3)
  link_summary <- summarise_linkage_results(context, "relationship", links, 5)
  stopifnot(date_summary$counts$recognised == 1, date_summary$counts$incomplete == 1,
    date_summary$counts$missing == 1, link_summary$counts$linked == 2,
    link_summary$counts$ambiguous == 1, link_summary$counts$unresolved_reference == 1,
    link_summary$counts$missing_reference == 1, length(analysis_row$candidates) == 2)
  close_repository(repo); repo <- open_repository(root)
  stopifnot(identical(freeze_validation_context(repo, config$config_id), context),
    verify_input(repo, input$version_id)$ok,
    identical(vapply(paths, digest::digest, character(1), file = TRUE, algo = "sha256", serialize = FALSE), hashes),
    nrow(list_operations(repo)) == 0L)
  evidence <- list(scope = "Synthetic hand-specified result contract examples, not detected findings",
    runtime = repo$root, config_id = config$config_id, context = context,
    date_summary = date_summary, linkage_summary = link_summary,
    date_rows = dates, ambiguous_date = analysis_row, linkage_rows = links,
    unchanged_source_hashes = TRUE, restart_preserved_context = TRUE, operations_created = 0)
  dir.create("evidence/validation-contracts", recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(evidence, "evidence/validation-contracts/manual-result.json", auto_unbox = TRUE, pretty = TRUE, null = "null")
  cat("Contract demonstration only; no checks executed.\n")
  print(date_summary$counts); print(link_summary$counts)
  cat("Runtime:", repo$root, "\nRestart preserved context; sources unchanged; zero operations created.\n")
}, finally = close_repository(repo))
