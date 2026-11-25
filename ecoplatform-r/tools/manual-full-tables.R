# Step 2B acceptance, from ecoplatform-r/. No scientific checks or user data exports.
# Rscript --vanilla tools/manual-full-tables.R
.libPaths(c(Sys.getenv("ECODATA_R_LIBRARY"), .libPaths()))
pkgload::load_all(".", quiet = TRUE)
examples <- Sys.getenv("ECODATA_EXAMPLES", unset = normalizePath("../../../data_examples", winslash = "/"))
runtime <- tempfile("ecodata-full-tables-")
repo <- open_repository(runtime)
on.exit <- NULL
paths <- list.files(examples, pattern = "[.](csv|zip)$", full.names = TRUE, ignore.case = TRUE)
if (!length(paths)) stop("No examples; set ECODATA_EXAMPLES")
summaries <- list()
for (path in paths) {
  hash <- digest::digest(path, file = TRUE, algo = "sha256", serialize = FALSE)
  upload <- data.frame(name = basename(path), size = file.info(path)$size,
    type = "", datapath = path, stringsAsFactors = FALSE)
  registered <- register_uploaded_inputs(repo, upload, basename(path), "manual-step2b")
  before <- nrow(list_operations(repo))
  input <- read_validation_tables(repo, registered$version_id, registered$config_id)
  p <- assess_validation_prerequisites(input)
  stopifnot(before == nrow(list_operations(repo)), !input$scientific_checks_executed,
    verify_input(repo, registered$version_id)$ok,
    identical(hash, digest::digest(path, file = TRUE, algo = "sha256", serialize = FALSE)))
  summaries[[basename(path)]] <- list(
    source_sha256 = hash, source_unchanged = TRUE,
    tables = lapply(input$tables, function(t) list(member = t$member,
      status = t$status, rows = t$population_count, columns = if(is.null(t$data))NULL else ncol(t$data),
      reason = t$reason, parser = t$parser)),
    linkage = lapply(p$linkage, function(x) list(status=x$status,reason=x$reason)),
    dates = lapply(p$dates, function(x) list(status=x$status,reason=x$reason)),
    unconfirmed_candidates = length(p$date_suggestions), scientific_rows_evaluated = 0)
  cat(basename(path), ": ",
    paste(vapply(input$tables, function(t) paste(t$member, t$status, t$population_count), character(1)), collapse="; "), "\n", sep="")
}
# Prove independence with one missing extension, using a synthetic archive.
stage <- tempfile("step2b-missing-member-"); dir.create(stage)
writeLines(c('<archive xmlns="http://rs.tdwg.org/dwc/text/">',
  '<core rowType="http://rs.tdwg.org/dwc/terms/Occurrence" fieldsTerminatedBy="," ignoreHeaderLines="1"><files><location>core.csv</location></files><id index="0"/><field index="1" term="http://rs.tdwg.org/dwc/terms/eventDate"/></core>',
  '<extension rowType="http://rs.tdwg.org/dwc/terms/MeasurementOrFact" fieldsTerminatedBy="," ignoreHeaderLines="1"><files><location>missing.csv</location></files><coreid index="0"/></extension></archive>'),file.path(stage,"meta.xml"))
writeLines(c("id,date","001,03/04/2020"),file.path(stage,"core.csv"))
archive <- file.path(stage,"missing-extension.zip")
zip::zipr(archive,c("meta.xml","core.csv"),root=stage)
registered <- register_uploaded_inputs(repo,data.frame(name=basename(archive),size=file.info(archive)$size,type="",datapath=archive),"Missing extension","manual-step2b")
input <- read_validation_tables(repo,registered$version_id,registered$config_id)
p <- assess_validation_prerequisites(input)
stopifnot(p$linkage[[1]]$status=="not_evaluated",p$dates[[1]]$status=="ready",
  p$dates[[1]]$scientific_rows_evaluated==0, input$tables[[1]]$data[[1]][1]=="001",
  input$tables[[1]]$data[[2]][1]=="03/04/2020",nrow(list_operations(repo))==0L)
summaries[["synthetic_missing_extension"]] <- list(linkage=p$linkage[[1]]$status,
  core_date=p$dates[[1]]$status, original_ambiguous_text_preserved=TRUE,scientific_rows_evaluated=0)
close_repository(repo)
dir.create("evidence/full-tables",recursive=TRUE,showWarnings=FALSE)
jsonlite::write_json(list(runtime=runtime,results=summaries),
  "evidence/full-tables/manual-result.json",auto_unbox=TRUE,pretty=TRUE,null="null")
cat("Missing extension: linkage not_evaluated; core date ready; zero scientific rows.\n")
cat("Original bytes unchanged; no operations created.\n")
