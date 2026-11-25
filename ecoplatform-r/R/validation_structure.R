# PRE-01/LNK-01/TMP-00 preparation only: no ID matching or date recognition.
find_prepared_table <- function(input,table_id) {
  found<-Filter(function(t)identical(t$table_id,table_id),input$tables)
  if(length(found)==1L)found[[1]] else NULL
}

prerequisite_record <- function(rule_id,family,status,reason,table=NULL,mapping=NULL) {
  list(rule_id=rule_id,family=family,status=status,reason=reason,
    table_id=if(is.null(table))NULL else table$table_id,
    population_count=if(is.null(table))NULL else table$population_count,
    eligible_rows=if(status=="ready"&&!is.null(table$population_count))table$population_count else 0L,
    mapping=mapping,scientific_rows_evaluated=0L)
}

prepared_schema_issue <- function(table,declared) {
  if(is.null(table))return("Declared table/member is unavailable")
  if(table$status!="complete")return(paste("Table/member is not completely readable:",table$reason))
  if(!contract_equal(table$schema,declared))return("Saved mapping schema/headers disagree with the actual source table")
  ""
}

prepared_key_issue <- function(table) {
  if(is.null(table)||is.null(table$declaration))return("No descriptor member declaration")
  if(table$status!="complete")return(paste("Declared member is not completely readable:",table$reason))
  key<-table$declaration$key
  if(is.null(key$position))return(paste("Unusable key index:",key$reason))
  if(key$position>=ncol(table$data))return("Declared key index/position is outside the actual table")
  ""
}

supported_occurrence <- function(type) type%in%c("http://rs.tdwg.org/dwc/terms/Occurrence","https://rs.tdwg.org/dwc/terms/Occurrence")
supported_measurement <- function(type) type%in%c("http://rs.tdwg.org/dwc/terms/MeasurementOrFact","https://rs.tdwg.org/dwc/terms/MeasurementOrFact",
  "http://rs.iobis.org/obis/terms/ExtendedMeasurementOrFact","https://rs.iobis.org/obis/terms/ExtendedMeasurementOrFact")
is_event_date_term <- function(term) term%in%c("http://rs.tdwg.org/dwc/terms/eventDate","https://rs.tdwg.org/dwc/terms/eventDate")

linkage_prerequisites <- function(input) {
  output<-list();saved<-input$configuration$validation_spec$linkage_mappings
  for(resource in input$resources) {
    tables<-Filter(function(t)identical(t$resource_id,resource$resource_id),input$tables)
    if(any(vapply(tables,function(t)identical(t$archive_mode,"plain_zip"),logical(1)))) {
      output<-c(output,plain_archive_linkage_prerequisites(input,resource,tables));next
    }
    declared<-Filter(function(t)!is.null(t$declaration),tables)
    core<-Filter(function(t)t$declaration$kind=="core",declared)
    extensions<-Filter(function(t)t$declaration$kind=="extension"&&supported_measurement(t$declaration$row_type),declared)
    if(!length(declared)) {
      archive<-tolower(tools::file_ext(resource$original_name))=="zip"
      output[[length(output)+1L]]<-prerequisite_record("LNK-01","linkage",if(archive)"not_evaluated" else "not_applicable",
        if(archive)paste("Archive declaration unavailable:",resource$reason) else "No declared archive relationship",tables[[1]])
      next
    }
    if(length(core)!=1L||!supported_occurrence(core[[1]]$declaration$row_type)||!length(extensions)) {
      output[[length(output)+1L]]<-prerequisite_record("LNK-01","linkage","not_evaluated",
        "A single supported occurrence core and measurement extension declaration are required",if(length(extensions))extensions[[1]] else NULL)
      next
    }
    core<-core[[1]]
    for(extension in extensions) {
      issue<-prepared_key_issue(core)
      if(!nzchar(issue))issue<-prepared_key_issue(extension)
      candidates<-Filter(function(m)m$core$table$resource_id==resource$resource_id&&m$extension$table$table_id==extension$table_id,saved)
      mapping<-NULL
      if(length(candidates)>1L)issue<-"Multiple saved relationship mappings require explicit selection"
      if(length(candidates)==1L) {
        mapping<-candidates[[1]]
        if(!mapping$confirmed)issue<-"Saved linkage mapping is not confirmed"
        if(mapping$confirmed && identical(mapping$source,"user")) {
          # Explicit operator evidence may supply missing indices; a known
          # immutable descriptor key still cannot be silently overwritten.
          issue<-prepared_schema_issue(core,mapping$core$table)
          if(!nzchar(issue))issue<-prepared_schema_issue(extension,mapping$extension$table)
          if(!nzchar(issue))for(pair in list(list(core,mapping$core$column$position),
            list(extension,mapping$extension$column$position))) {
            declared<-pair[[1]]$declaration$key$position
            if(is.null(declared)&&!identical(pair[[1]]$declaration$key$state,"missing"))issue<-"Ambiguous or invalid descriptor key requires a corrected source"
            if(!is.null(declared)&&declared!=pair[[2]])issue<-"Saved linkage columns disagree with descriptor id/coreid indices"
          }
        } else {
          if(!nzchar(issue))issue<-prepared_schema_issue(core,mapping$core$table)
          if(!nzchar(issue))issue<-prepared_schema_issue(extension,mapping$extension$table)
          if(!nzchar(issue)&&(mapping$core$column$position!=core$declaration$key$position||
            mapping$extension$column$position!=extension$declaration$key$position))issue<-"Saved linkage columns disagree with descriptor id/coreid indices"
        }
      }
      if(!nzchar(issue)&&is.null(mapping)) mapping<-new_linkage_mapping(core$schema,core$declaration$key$position,
        extension$schema,extension$declaration$key$position,paste0("descriptor-link:",extension$table_id),
        "descriptor-reader",paste("meta.xml",core$declaration$descriptor_member,"SHA-256",core$declaration$descriptor_sha256,"id/coreid indices"),TRUE)
      output[[length(output)+1L]]<-prerequisite_record("LNK-01","linkage",if(nzchar(issue))"not_evaluated" else "ready",
        if(nzchar(issue))issue else "Supported descriptor relationship and exact key/reference columns are usable; matching not executed",extension,mapping)
    }
  }
  output
}

suggest_date_mappings <- function(table) {
  if(is.null(table$schema)||is.null(table$data))return(list())
  headers<-names(table$data);normalized<-tolower(trimws(headers))
  roles<-list(year=which(normalized%in%c("year","anno","yyyy")),day=which(normalized%in%c("day","giorno","dd")),month=which(normalized%in%c("month","mese","mm")))
  suggestions<-list();group_columns<-integer()
  if(all(lengths(roles)==1L)) {
    columns<-vapply(roles,function(x)x-1L,integer(1));group_columns<-unname(columns+1L)
    suggestions[[1]]<-new_date_mapping(table$schema,paste0("suggested-split:",table$table_id),"unconfirmed_date",columns,
      "suggested","mapping-suggester","Unique day/month/year header candidates; operator must confirm roles",FALSE)
  }
  for(i in seq_along(headers)) {
    if(i%in%group_columns)next
    sample<-utils::head(table$data[[i]][!vapply(table$data[[i]],blank_contract_value,logical(1))],8L)
    header_candidate<-grepl("date|data|fecha|datum|time",normalized[[i]])
    value_candidate<-length(sample)>0L&&any(grepl("^([0-9]{4}([-/][0-9]{1,2}){0,2}|[0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{4})([T ].*)?$",sample))
    if(header_candidate||value_candidate)suggestions[[length(suggestions)+1L]]<-new_date_mapping(table$schema,
      paste0("suggested-field:",table$table_id,":",i-1L),"unconfirmed_date",c(value=i-1L),"suggested","mapping-suggester",
      paste("Unconfirmed candidate from",if(header_candidate)"header" else "bounded sample values","; no role or date pattern confirmed"),FALSE)
  }
  suggestions
}

date_prerequisites <- function(input) {
  output<-list();suggestions<-list();saved<-input$configuration$validation_spec$date_mappings
  for(table in input$tables) {
    mappings<-Filter(function(m)identical(m$table$table_id,table$table_id),saved)
    if(length(mappings)) {
      for(mapping in mappings) {
        issue<-prepared_schema_issue(table,mapping$table)
        if(!mapping$confirmed)issue<-"Date mapping/role has not been confirmed"
        if(!nzchar(issue)&&mapping$source=="descriptor") {
          positions<-vapply(Filter(function(f)is_event_date_term(f$term)&&!is.null(f$position),table$declaration$fields),function(f)f$position,numeric(1))
          if(!mapping$date_role%in%c("eventDate","http://rs.tdwg.org/dwc/terms/eventDate","https://rs.tdwg.org/dwc/terms/eventDate"))issue<-"Saved descriptor date role disagrees with the eventDate declaration"
          if(!nzchar(issue)&&(length(mapping$columns)!=1L||sum(positions==mapping$columns$value$position)!=1L))issue<-"Saved descriptor date mapping is not supported by the actual field declaration"
        }
        output[[length(output)+1L]]<-prerequisite_record("TMP-00","date",if(nzchar(issue))"not_evaluated" else "ready",
          if(nzchar(issue))issue else "Confirmed date mapping matches actual headers/positions; recognition not executed",table,mapping)
      }
    }
    # Explicit mappings override only the positions they actually cover.
    covered<-unlist(lapply(mappings,function(m)lapply(m$columns,function(c)c$position)),use.names=FALSE)
    fields<-Filter(function(f)is_event_date_term(f$term)&&(is.null(f$position)||!f$position%in%covered),table$declaration$fields)
    positions<-vapply(fields,function(f)if(is.null(f$position))NA_real_ else f$position,numeric(1))
    duplicate_positions<-positions[duplicated(positions)&!is.na(positions)]
    fields<-fields[!duplicated(positions)|is.na(positions)]
    if(length(fields)) {
      for(i in seq_along(fields)) {
        field<-fields[[i]];mapping<-NULL
        issue<-if(!is.null(field$position)&&field$position%in%duplicate_positions)"Ambiguous duplicate eventDate position in descriptor" else if(table$status!="complete")paste("Date member not completely readable:",table$reason) else if(is.null(field$position))paste("Date index is unusable:",field$reason) else if(field$position>=ncol(table$data))"Date index/position is outside the actual table" else ""
        if(!nzchar(issue))mapping<-new_date_mapping(table$schema,paste0("descriptor-date:",table$table_id,":",field$position),
          "eventDate",c(value=field$position),"descriptor","descriptor-reader",
          paste("Declared",field$term,"in",table$declaration$descriptor_member,"SHA-256",table$declaration$descriptor_sha256),TRUE)
        output[[length(output)+1L]]<-prerequisite_record("TMP-00","date",if(nzchar(issue))"not_evaluated" else "ready",
          if(nzchar(issue))issue else "Usable eventDate declaration; recognition not executed",table,mapping)
      }
    }
    # An answer covers its own fields, never all other dates in the table.
    assigned<-c(covered,positions[!is.na(positions)])
    candidates<-Filter(function(m) {
      proposed<-vapply(m$columns,function(c)c$position,numeric(1))
      !any(proposed%in%assigned)
    },suggest_date_mappings(table))
    suggestions<-c(suggestions,candidates)
    if(length(candidates))for(mapping in candidates)output[[length(output)+1L]]<-prerequisite_record("TMP-00","date","not_evaluated",
      "Date candidate requires explicit confirmation of role/component assignments",table,mapping)
    if(!length(candidates)&&!length(mappings)&&!length(fields))
      output[[length(output)+1L]]<-prerequisite_record("TMP-00","date","not_evaluated",
        if(table$status!="complete")paste("Table/member unavailable:",table$reason) else "No declared/confirmed date mapping; manual mapping required",table)
  }
  # Saved mappings for absent members are not silently dropped.
  missing<-Filter(function(m)is.null(find_prepared_table(input,m$table$table_id)),saved)
  for(mapping in missing)output[[length(output)+1L]]<-prerequisite_record("TMP-00","date","not_evaluated","Saved mapping table/member is absent",mapping=mapping)
  list(checks=output,suggestions=suggestions)
}

#' Assess independent full-table prerequisites for linkage and date checks
#'
#' Pure preparation: verifies actual mapping schemas and descriptor indices.
#' It neither compares identifiers nor recognises date patterns. Ready means
#' eligible for a later quality check, never a scientific pass. Suggestions
#' remain unconfirmed and do not modify saved configurations.
#' @param input Preparation returned by read_validation_tables().
#' @return Independent PRE-01 table outcomes, LNK-01 relationship prerequisites,
#'   TMP-00 date prerequisites and unconfirmed candidate mappings. Population and
#'   eligible row counts remain distinct from scientific_rows_evaluated (zero).
#' @export
assess_validation_prerequisites <- function(input) {
  if(!identical(input$contract_version,"validation-preparation-1.0"))stop("Unsupported validation preparation")
  # Technical ambiguity remains pending until the actual settings are approved.
  # Only this assessment view is gated; complete lexical source data stays intact.
  for(i in seq_along(input$tables)) {
    table<-input$tables[[i]]
    if(table$status=="complete"&&(isTRUE(table$settings_pending)||clarification_parser_pending(input$configuration,table$resource_id))) {
      input$tables[[i]]$status<-"unconfirmed"
      input$tables[[i]]$reason<-"Parser settings require explicit user confirmation"
    }
  }
  dates<-date_prerequisites(input)
  list(contract_version="validation-prerequisites-1.0",version_id=input$version_id,
    config_id=input$config_id,config_hash=input$config_hash,
    table_checks=lapply(input$tables,function(table)prerequisite_record("PRE-01","table",
      if(table$status=="complete")"ready" else "not_evaluated",table$reason,table)),
    linkage=linkage_prerequisites(input),dates=dates$checks,date_suggestions=dates$suggestions,
    scientific_checks_executed=FALSE)
}
