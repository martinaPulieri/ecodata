# Clarification requests are derived from exact input/configuration snapshots.
# They are ephemeral; only explicitly approved answers become configuration data.
clarification_receipts <- function(config) {
  if(is.null(config$clarifications)) list() else config$clarifications
}

validate_clarification_receipts <- function(receipts, version_id, resource_ids) {
  if(!is.list(receipts)) stop("Clarification receipts must be a list")
  ids <- character()
  for(receipt in receipts) {
    if(!identical(receipt$contract_version,"clarification-answer-1.0") ||
       !isTRUE(receipt$approved) || !identical(receipt$version_id,version_id) ||
       !receipt$resource_id %in% resource_ids) stop("Invalid approved clarification receipt")
    for(field in c("question_id","question_key","base_config_id","source_sha256",
                   "evidence","actor_id","approved_at"))
      scalar_text(receipt[[field]],paste("receipt",field))
    contract_enum(receipt$type,c("parser","archive_parser","archive_linkage","date_mapping","linkage_mapping","source_repair"),"receipt type")
    if(!is.list(receipt$answer)) stop("Invalid clarification answer")
    ids <- c(ids,receipt$question_id)
  }
  if(anyDuplicated(ids)) stop("Duplicate approved clarification question")
  invisible(receipts)
}

# Approval is bound to the actual parser, not just a historic resource-level flag.
clarification_parser_pending <- function(config, resource_id) {
  evidence <- config$parser_detection[[resource_id]]
  if(is.null(evidence) || isTRUE(evidence$status%in%c("detected","archive_declared"))) return(FALSE)
  approved <- Filter(function(r)r$type=="parser" && isTRUE(r$approved) &&
    identical(r$resource_id,resource_id) &&
    identical(r$source_sha256,evidence$resource_sha256) &&
    contract_equal(r$answer,config$parsers[[resource_id]]),clarification_receipts(config))
  !length(approved)
}

clarification_question <- function(input,type,resource_id,key,reason,checks,
  table_id=NULL,mapping=NULL,core_table_id=NULL,suggestions=list()) {
  resource <- Filter(function(r)identical(r$resource_id,resource_id),input$resources)[[1]]
  stable <- paste(type,resource_id,key,sep=":")
  prior <- Filter(function(r)identical(r$question_key,stable) &&
    identical(r$source_sha256,resource$sha256),clarification_receipts(input$configuration))
  list(question_id=hash_text(paste(input$config_id,input$config_hash,stable,reason,sep=":")),
    question_key=stable,type=type,resource_id=resource_id,original_name=resource$original_name,
    source_sha256=resource$sha256,table_id=table_id,member=if(is.null(table_id))NULL else find_prepared_table(input,table_id)$member,core_table_id=core_table_id,
    mapping=mapping,reason=reason,dependent_checks=as.list(checks),
    suggestions=suggestions,status=if(type=="source_repair"&&length(prior))"awaiting_source" else "pending",
    last_answer=if(length(prior))utils::tail(prior,1)[[1]] else NULL)
}

build_clarification_questions <- function(input,p) {
  questions <- list()
  add <- function(q) questions[[length(questions)+1L]] <<- q
  for(resource in input$resources) {
    tables <- Filter(function(t)t$resource_id==resource$resource_id,input$tables)
    if(!isTRUE(resource$integrity_ok)) {
      add(clarification_question(input,"source_repair",resource$resource_id,"integrity",
        "Input integrity failed: supply a new verified source; parser or mapping answers cannot repair changed bytes.",c("PRE-01","LNK-01","TMP-00")))
      next
    }
    if(any(vapply(tables,function(t)identical(t$archive_mode,"plain_zip"),logical(1)))) {
      questions<-c(questions,plain_archive_questions(input,p,resource,tables));next
    }
    tabular <- is_standalone_table(resource$original_name)
    unreadable <- any(vapply(tables,function(t)t$status!="complete",logical(1)))
    if(tabular && (unreadable || clarification_parser_pending(input$configuration,resource$resource_id))) {
      reason <- if(unreadable)paste("Confirm parser settings or supply a corrected source:",tables[[1]]$reason) else
        "Ambiguous/unresolved format requires explicit confirmation before dependent checks"
      proposal <- input$configuration$parsers[[resource$resource_id]]
      add(clarification_question(input,"parser",resource$resource_id,"settings",reason,
        c("PRE-01","TMP-00"),suggestions=list(list(answer=proposal,confirmed=FALSE,
          evidence="Current saved settings; an unconfirmed starting point, not a verified solution"))))
    } else if(!tabular && unreadable) {
      failed <- Filter(function(t)t$status!="complete",tables)
      for(table in failed) add(clarification_question(input,"source_repair",resource$resource_id,
        table$table_id,paste("Provide the missing/corrected source or supported descriptor:",table$reason),
        c("PRE-01","LNK-01","TMP-00"),table$table_id))
    }
  }
  for(result in p$dates) {
    if(result$status!="not_evaluated" || is.null(result$table_id)) next
    table <- find_prepared_table(input,result$table_id)
    if(is.null(table) || table$status!="complete") next
    mapping <- result$mapping
    key <- if(is.null(mapping))paste0(table$table_id,":manual-date") else mapping$mapping_id
    suggestions <- if(is.null(mapping))list() else {
      candidate<-mapping;candidate$source<-"suggested";candidate$confirmed<-FALSE;list(candidate)
    }
    add(clarification_question(input,"date_mapping",table$resource_id,key,result$reason,
      "TMP-00",table$table_id,mapping=mapping,suggestions=suggestions))
  }
  for(resource in input$resources) {
    tables <- Filter(function(t)t$resource_id==resource$resource_id,input$tables)
    if(any(vapply(tables,function(t)identical(t$archive_mode,"plain_zip"),logical(1))))next
    core <- Filter(function(t)!is.null(t$declaration)&&t$declaration$kind=="core"&&
      supported_occurrence(t$declaration$row_type),tables)
    extensions <- Filter(function(t)!is.null(t$declaration)&&t$declaration$kind=="extension"&&
      supported_measurement(t$declaration$row_type),tables)
    results <- Filter(function(r)r$status=="not_evaluated" &&
      (is.null(r$table_id) || any(vapply(tables,function(t)t$table_id==r$table_id,logical(1)))),p$linkage)
    if(!length(results) || tolower(tools::file_ext(resource$original_name))!="zip") next
    if(length(core)==1L && core[[1]]$status=="complete" && length(extensions)) {
      for(extension in extensions) {
        result <- Filter(function(r)identical(r$table_id,extension$table_id),results)
        if(!length(result) || extension$status!="complete") next
        usable<-all(vapply(list(core[[1]],extension),function(t) {
          key<-t$declaration$key
          identical(key$state,"missing")||(!is.null(key$position)&&identical(key$state,"declared")&&key$position<ncol(t$data))
        },logical(1)))
        if(!usable) {
          add(clarification_question(input,"source_repair",resource$resource_id,paste0("keys:",extension$table_id),
            paste("Ambiguous, invalid or out-of-range descriptor key; provide a corrected declaration.",result[[1]]$reason),
            "LNK-01",extension$table_id))
          next
        }
        proposal <- list(core_position=core[[1]]$declaration$key$position,
          extension_position=extension$declaration$key$position)
        add(clarification_question(input,"linkage_mapping",resource$resource_id,extension$table_id,
          result[[1]]$reason,"LNK-01",extension$table_id,core_table_id=core[[1]]$table_id,
          mapping=result[[1]]$mapping,suggestions=list(list(answer=proposal,confirmed=FALSE,
            evidence="Declared indices only; missing indices require the data owner's answer"))))
      }
    } else if(!any(vapply(questions,function(q)q$type=="source_repair"&&q$resource_id==resource$resource_id,logical(1)))) {
      add(clarification_question(input,"source_repair",resource$resource_id,"relationship",
        "Provide a supported Occurrence/measurement declaration or explain why this relationship is unavailable. Notes do not establish applicability.",
        "LNK-01"))
    }
  }
  questions
}

#' Prepare missing-information questions without saving answers
#' @param repo Open repository handle.
#' @param version_id Exact active immutable input version.
#' @param config_id Exact configuration to inspect (historical reads allowed).
#' @param expected_workspace_revision Optional displayed lifecycle revision.
#' @return Questions, evidence, unapproved suggestions, preparation and independent
#'   prerequisite outcomes. Reading never creates a configuration or approval.
#' @export
prepare_clarifications <- function(repo,version_id,config_id,expected_workspace_revision=NULL) {
  input <- read_validation_tables(repo,version_id,config_id,
    expected_workspace_revision=expected_workspace_revision)
  p <- assess_validation_prerequisites(input)
  list(contract_version="clarification-questions-1.0",version_id=version_id,config_id=config_id,
    config_hash=input$config_hash,workspace_revision=input$workspace_revision,
    questions=build_clarification_questions(input,p),preparation=input,prerequisites=p)
}
