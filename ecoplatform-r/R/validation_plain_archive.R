# Plain archives have no descriptor-derived relationship authority.
plain_archive_linkage_prerequisites <- function(input,resource,tables) {
  mappings<-Filter(function(m)identical(m$core$table$resource_id,resource$resource_id),
    input$configuration$validation_spec$linkage_mappings)
  if(!length(mappings))return(list(prerequisite_record("LNK-01","linkage",
    if(length(tables)<2L)"not_applicable" else "not_evaluated",
    if(length(tables)<2L)"No multi-table archive relationship is available" else
      "Plain ZIP relationship and exact table/key assignments require explicit approval")))
  lapply(mappings,function(mapping) {
    core<-find_prepared_table(input,mapping$core$table$table_id)
    extension<-find_prepared_table(input,mapping$extension$table$table_id)
    issue<-prepared_schema_issue(core,mapping$core$table)
    if(!nzchar(issue))issue<-prepared_schema_issue(extension,mapping$extension$table)
    if(!identical(mapping$source,"user")||!isTRUE(mapping$confirmed))
      issue<-"Plain ZIP relationship requires a confirmed user mapping; no descriptor exists"
    count<-sum(vapply(mappings,function(m)identical(m$extension$table$table_id,mapping$extension$table$table_id),logical(1)))
    if(count>1L)issue<-"Multiple saved relationship mappings require explicit selection"
    prerequisite_record("LNK-01","linkage",if(nzchar(issue))"not_evaluated" else "ready",
      if(nzchar(issue))issue else "User-approved table/key relationship; identifier matching not executed",
      extension,mapping)
  })
}

plain_linkage_suggestion <- function(tables,mapping=NULL) {
  complete<-Filter(function(t)t$status=="complete"&&!is.null(t$schema),tables)
  core<-Filter(function(t)grepl("^occurrence[.](csv|tsv|txt)$",basename(t$member),ignore.case=TRUE),complete)
  ext<-Filter(function(t)grepl("^(extended)?measurementorfact[.](csv|tsv|txt)$",basename(t$member),ignore.case=TRUE),complete)
  if(!is.null(mapping)) {
    core<-Filter(function(t)t$table_id==mapping$core$table$table_id,complete)
    ext<-Filter(function(t)t$table_id==mapping$extension$table$table_id,complete)
  }
  if(length(core)!=1L||length(ext)!=1L)return(list())
  unique_id<-function(t){p<-which(tolower(names(t$data))=="id");if(length(p)==1L)p-1L else NULL}
  list(list(answer=list(core_table_id=core[[1]]$table_id,extension_table_id=ext[[1]]$table_id,
    core_position=if(is.null(mapping))unique_id(core[[1]]) else mapping$core$column$position,
    extension_position=if(is.null(mapping))unique_id(ext[[1]]) else mapping$extension$column$position),
    confirmed=FALSE,evidence="Filenames and exact id headers suggest a possible relationship only. Confirm key meaning and scope; dataset_id may also matter. No matching or uniqueness test executed."))
}

plain_archive_questions <- function(input,p,resource,tables) {
  output<-list()
  for(table in tables) {
    if(!is.null(table$proposed_setting)&&(isTRUE(table$settings_pending)||table$status!="complete"))
      output[[length(output)+1L]]<-clarification_question(input,"archive_parser",resource$resource_id,
        table$table_id,paste("Confirm this member's encoding, separator, quote and header presence.",table$reason),
        c("PRE-01","LNK-01","TMP-00"),table$table_id,
        suggestions=list(list(answer=table$proposed_setting,confirmed=FALSE,
          evidence=paste(table$detection$message,"Header presence is a proposal, not established by byte detection."))))
    else if(table$status!="complete")
      output[[length(output)+1L]]<-clarification_question(input,"source_repair",resource$resource_id,
        table$table_id,paste("Member unavailable; retry within supported limits or provide a usable source:",table$reason),
        c("PRE-01","LNK-01","TMP-00"),table$table_id)
  }
  # Reassess only this resource. A sibling's missing relationship must never
  # reopen a user-approved relationship here. Raw readable tables also let
  # already-approved semantics wait solely on their own parser prerequisite.
  results<-Filter(function(r)r$status=="not_evaluated",
    plain_archive_linkage_prerequisites(input,resource,tables))
  readable<-Filter(function(t)t$status=="complete"&&!is.null(t$schema),tables)
  if(length(results)&&length(readable)>=2L) {
    saved<-Filter(function(m)identical(m$core$table$resource_id,resource$resource_id),
      input$configuration$validation_spec$linkage_mappings)
    mapping<-if(length(saved)==1L)saved[[1]] else NULL
    q<-clarification_question(input,"archive_linkage",resource$resource_id,"relationship",
      "No meta.xml declares this relationship. Select both tables and their exact keys; confirm identifier meaning and dataset scope.",
      "LNK-01",mapping=mapping,suggestions=plain_linkage_suggestion(tables,mapping))
    q$table_choices<-lapply(readable,function(t)list(table_id=t$table_id,member=t$member))
    output[[length(output)+1L]]<-q
  }
  output
}
