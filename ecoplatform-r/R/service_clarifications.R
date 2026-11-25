# Resolve all identities from freshly read server-side context, never from form
# headers or guessed resource names. Drafts do not carry writable SQL payloads.
clarification_context <- function(repo, request) {
  if(!identical(request$contract_version,"clarification-questions-1.0"))stop("Invalid clarification request")
  cfg <- get_configuration(repo,request$config_id)
  if(!identical(cfg$version_id,request$version_id)||!identical(cfg$context_hash,request$config_hash))
    stop("Clarification configuration context mismatch")
  assert_workspace_active(repo,cfg$version_id,request$workspace_revision)
  if(utils::tail(list_configurations(repo,cfg$version_id)$config_id,1)!=cfg$config_id)
    stop("stale clarification; reload the latest configuration")
  cfg
}

clarification_answer <- function(input,question,answer,actor_id,evidence) {
  scalar_text(actor_id,"actor_id");scalar_text(evidence,"answer evidence")
  if(!is.list(answer))stop("Answer must be a structured list")
  resource<-Filter(function(r)identical(r$resource_id,question$resource_id),input$resources)
  if(question$type!="source_repair"&&(length(resource)!=1L||!isTRUE(resource[[1]]$integrity_ok)))stop("Input integrity failed; supply a new verified source")
  cfg <- input$configuration
  if(question$type=="parser") return(validate_parser(answer))
  if(question$type=="archive_parser")return(validate_archive_setting(answer))
  if(question$type=="archive_linkage") {
    if(!setequal(names(answer),c("core_table_id","extension_table_id","core_position","extension_position"))||anyDuplicated(names(answer)))stop("Supply both tables and exact key positions")
    core<-find_prepared_table(input,answer$core_table_id);extension<-find_prepared_table(input,answer$extension_table_id)
    for(t in list(core,extension))if(is.null(t)||t$status!="complete"||!identical(t$archive_mode,"plain_zip")||t$resource_id!=question$resource_id)stop("Select readable tables within this exact plain ZIP resource")
    id<-if(is.null(question$mapping))paste0("clarified-link:",extension$table_id) else question$mapping$mapping_id
    return(new_linkage_mapping(core$schema,answer$core_position,extension$schema,answer$extension_position,id,actor_id,evidence,TRUE,source="user"))
  }
  if(question$type=="source_repair") {
    if(!setequal(names(answer),"note"))stop("Supply an explanatory note")
    scalar_text(answer$note,"source repair note")
    return(list(note=answer$note))
  }
  table <- find_prepared_table(input,question$table_id)
  if(is.null(table)||table$status!="complete")stop("Answer table is not completely readable")
  if(question$type=="date_mapping") {
    allowed <- c("date_role","columns","date_order","date_order_evidence")
    if(any(!names(answer)%in%allowed)||anyDuplicated(names(answer)))stop("Unknown date answer fields")
    columns <- answer$columns
    if(is.list(columns))columns<-unlist(columns,use.names=TRUE)
    id <- if(is.null(question$mapping))paste0("clarified-date:",substr(question$question_id,1,20)) else question$mapping$mapping_id
    return(new_date_mapping(table$schema,id,answer$date_role,columns,"user",actor_id,evidence,TRUE,
      answer$date_order,if(is.null(answer$date_order_evidence))"" else answer$date_order_evidence))
  }
  if(question$type=="linkage_mapping") {
    if(!setequal(names(answer),c("core_position","extension_position")))stop("Supply exact core and extension key positions")
    core <- find_prepared_table(input,question$core_table_id)
    if(is.null(core)||core$status!="complete")stop("Core table is not completely readable")
    for(pair in list(list(core,answer$core_position),list(table,answer$extension_position))) {
      column_contract(pair[[1]]$schema,pair[[2]])
      declared <- pair[[1]]$declaration$key$position
      if(is.null(declared)&&!identical(pair[[1]]$declaration$key$state,"missing"))stop("Ambiguous or invalid descriptor key; supply a corrected source")
      if(!is.null(declared)&&declared!=pair[[2]])stop("Answer conflicts with the original descriptor key; supply a corrected source")
    }
    id <- if(is.null(question$mapping))paste0("clarified-link:",table$table_id) else question$mapping$mapping_id
    return(new_linkage_mapping(core$schema,answer$core_position,table$schema,answer$extension_position,
      id,actor_id,evidence,TRUE,source="user"))
  }
  stop("Unsupported question type")
}

# A stable representation binds the exact reviewed values and operator evidence.
draft_digest <- function(draft) {
  draft$draft_hash <- NULL
  hash_text(json_text(draft))
}

#' Review an answer without accepting or saving it
#' @param repo Open repository handle.
#' @param request Question set returned by prepare_clarifications().
#' @param question_id Exact displayed question identifier.
#' @param answer Structured parser settings, date role/columns, linkage positions,
#'   or source-repair note. Date positions are zero-based.
#' @param evidence Operator explanation supporting the supplied answer.
#' @param actor_id Explicit local operator label, not authentication.
#' @return Server-held exact draft. Reviewing it never saves or confirms anything.
#' @export
preview_clarification_answer <- function(repo,request,question_id,answer,evidence,actor_id) {
  clarification_context(repo,request)
  # Rebuild requests rather than trusting client-supplied schemas/suggestions.
  fresh <- prepare_clarifications(repo,request$version_id,request$config_id,request$workspace_revision)
  found <- Filter(function(q)identical(q$question_id,question_id),fresh$questions)
  if(length(found)!=1L)stop("Unknown or changed clarification question")
  normalized <- clarification_answer(fresh$preparation,found[[1]],answer,actor_id,evidence)
  draft <- list(contract_version="clarification-draft-1.0",
    version_id=request$version_id,config_id=request$config_id,config_hash=request$config_hash,
    workspace_revision=request$workspace_revision,question_id=question_id,
    question=found[[1]],answer=answer,reviewed_answer=normalized,
    replacements=clarification_replacements(fresh$preparation,found[[1]],normalized),evidence=evidence,actor_id=actor_id)
  draft$draft_hash <- draft_digest(draft)
  draft
}

#' Approve an exact reviewed answer into a new configuration revision
#' @param repo Open repository handle.
#' @param draft Exact draft from preview_clarification_answer().
#' @param approved Must be explicitly TRUE. Missing/FALSE saves nothing.
#' @return New append-only configuration with approval evidence and an updated
#'   parser/mapping where applicable. A source-repair note leaves checks pending.
#'   Stale, historical, removed, tampered or cross-context submissions are rejected.
#' @export
approve_clarification_answer <- function(repo,draft,approved=FALSE) {
  if(!isTRUE(approved))stop("Explicit user approval is required")
  if(!identical(draft$contract_version,"clarification-draft-1.0") ||
     !identical(draft$draft_hash,draft_digest(draft)))stop("Changed or invalid reviewed draft")
  request <- list(contract_version="clarification-questions-1.0",version_id=draft$version_id,
    config_id=draft$config_id,config_hash=draft$config_hash,workspace_revision=draft$workspace_revision)
  cfg <- clarification_context(repo,request)
  rebuilt <- preview_clarification_answer(repo,request,draft$question_id,
    draft$answer,draft$evidence,draft$actor_id)
  if(!contract_equal(rebuilt$reviewed_answer,draft$reviewed_answer) ||
     !contract_equal(rebuilt$replacements,draft$replacements)||
     !contract_equal(rebuilt$question,draft$question))stop("Changed source/question/draft; review again")
  question <- rebuilt$question
  spec <- cfg$validation_spec
  if(question$type %in% c("date_mapping","linkage_mapping","archive_linkage")) {
    if(is.null(spec))spec<-new_validation_spec()
    slot <- if(question$type=="date_mapping")"date_mappings" else "linkage_mappings"
    mapping <- rebuilt$reviewed_answer
    for(target_slot in c("date_mappings","linkage_mappings")) {
      removed<-vapply(Filter(function(x)x$slot==target_slot,rebuilt$replacements),function(x)x$mapping_id,character(1))
      spec[[target_slot]]<-Filter(function(m)!m$mapping_id%in%removed,spec[[target_slot]])
    }
    spec[[slot]] <- c(spec[[slot]],list(mapping))
    validate_validation_spec(spec,cfg$version_id)
  }
  settings<-cfg$archive_settings
  if(question$type=="archive_parser") {
    if(is.null(settings))settings<-list()
    settings[[question$resource_id]][[question$member]]<-rebuilt$reviewed_answer
  }
  parsers <- cfg$parsers
  if(question$type=="parser")parsers[[question$resource_id]]<-rebuilt$reviewed_answer
  recorded_question<-question
  recorded_question$last_answer<-NULL # History already retains earlier receipts.
  receipt <- list(contract_version="clarification-answer-1.0",
    question_id=question$question_id,question_key=question$question_key,
    type=question$type,version_id=cfg$version_id,base_config_id=cfg$config_id,
    resource_id=question$resource_id,source_sha256=question$source_sha256,
    question=recorded_question,superseded_mappings=rebuilt$replacements,answer=if(question$type=="parser")rebuilt$reviewed_answer else rebuilt$answer,
    applied_value=rebuilt$reviewed_answer,approved=TRUE,actor_id=rebuilt$actor_id,
    evidence=rebuilt$evidence,approved_at=utc_now())
  save_configuration(repo,cfg$version_id,parsers=parsers,metadata=cfg$metadata,schema=cfg$schema,
    parser_detection=cfg$parser_detection,validation_spec=spec,archive_settings=settings,
    clarifications=c(clarification_receipts(cfg),list(receipt)),
    expected_revision=cfg$revision,actor_id=rebuilt$actor_id,
    expected_workspace_revision=draft$workspace_revision)
}

# Mapping retirement is part of the reviewed draft, never a silent side effect.
# Keep valid mappings on independent tables; retire conflicting old schemas so
# they can be clarified again against actual headers, retaining old revisions.
clarification_replacements <- function(input,question,mapping) {
  if(!question$type%in%c("date_mapping","linkage_mapping","archive_linkage"))return(list())
  targets<-if(question$type=="date_mapping")list(mapping$table) else
    list(mapping$core$table,mapping$extension$table)
  output<-list()
  spec<-input$configuration$validation_spec
  for(slot in c("date_mappings","linkage_mappings"))for(old in spec[[slot]]) {
    old_tables<-if(slot=="date_mappings")list(old$table) else list(old$core$table,old$extension$table)
    stale<-any(vapply(old_tables,function(t)any(vapply(targets,function(target)
      identical(t$table_id,target$table_id)&&!contract_equal(t,target),logical(1))),logical(1)))
    same_relationship<-question$type%in%c("linkage_mapping","archive_linkage")&&slot=="linkage_mappings"&&
      identical(old$extension$table$table_id,mapping$extension$table$table_id)
    if(old$mapping_id==mapping$mapping_id||same_relationship||stale)
      output[[length(output)+1L]]<-list(mapping_id=old$mapping_id,slot=slot,
        reason=if(stale)"Stale schema: must be clarified again against current headers" else
          if(same_relationship)"Replace competing mappings for this relationship" else "Replace the selected mapping",
        role=if(slot=="date_mappings")old$date_role else "linkage")
  }
  output
}
