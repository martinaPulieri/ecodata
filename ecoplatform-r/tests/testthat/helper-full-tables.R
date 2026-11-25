full_archive <- function(core = "id,occurrenceID,Date observed\n001,obs-a,2020-03-15\n002,obs-b,03/04/2020\n",
  extension = "coreid,value\n001,1\n002,2\n", descriptor = NULL, include_extension = TRUE) {
  stage <- tempfile("full-read-fixtures-"); dir.create(stage)
  if (is.null(descriptor)) descriptor <- paste0('<archive xmlns="http://rs.tdwg.org/dwc/text/">',
    '<core rowType="http://rs.tdwg.org/dwc/terms/Occurrence" fieldsTerminatedBy="," ignoreHeaderLines="1"><files><location>core.csv</location></files><id index="0"/><field index="1" term="http://rs.tdwg.org/dwc/terms/occurrenceID"/><field index="2" term="http://rs.tdwg.org/dwc/terms/eventDate"/></core>',
    '<extension rowType="http://rs.tdwg.org/dwc/terms/MeasurementOrFact" fieldsTerminatedBy="," ignoreHeaderLines="1"><files><location>measurements.csv</location></files><coreid index="0"/><field index="1" term="http://rs.tdwg.org/dwc/terms/measurementValue"/></extension></archive>')
  writeBin(charToRaw(descriptor), file.path(stage,"meta.xml"))
  writeBin(charToRaw(core), file.path(stage,"core.csv"))
  files <- c("meta.xml","core.csv")
  if (include_extension) {writeBin(charToRaw(extension),file.path(stage,"measurements.csv"));files <- c(files,"measurements.csv")}
  path <- tempfile(fileext=".zip"); zip::zipr(path,files,root=stage)
  path
}

full_fixture <- function(repo, path, ...) {
  v <- register_input(path,list(title="Full-table test"),repo)
  cfg <- make_config(repo,v$version_id,...)
  list(v=v,cfg=cfg)
}
