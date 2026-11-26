# Workspace integration kept separate from upload, preview and lifecycle code.
# Draft values live on the server and are never read again from controls at
# approval time. The modal is the exact object the operator is approving.
workspace_clarifications <- function(input,output,session,repo,current_context,
  check_form,state,refresh_configs,tell,attempt) {
  ns <- session$ns
  local <- shiny::reactiveValues(request=NULL,draft=NULL,link_suggestion=NULL)
  shiny::observeEvent(current_context()$token,{
    local$request<-NULL;local$draft<-NULL;local$link_suggestion<-NULL
    shiny::removeModal(session=session)
  },ignoreInit=FALSE)

  current_question <- shiny::reactive({
    shiny::req(local$request,input$clarify_question)
    found<-Filter(function(q)identical(q$question_id,input$clarify_question),local$request$questions)
    shiny::req(length(found)==1L)
    found[[1]]
  })
  shiny::observeEvent(input$clarify_load,attempt(function() {
    ctx<-check_form()
    local$draft<-NULL;local$request<-NULL
    local$request<-shiny::withProgress(message="Checking required information",value=0.2,
      prepare_clarifications(repo,ctx$version_id,ctx$config$config_id,ctx$workspace_revision))
    tell("Information checked. Suggestions await your approval.","info")
  }))

  output$clarification_panel <- shiny::renderUI({
    ctx<-current_context()
    latest<-utils::tail(list_configurations(repo,ctx$version_id)$config_id,1)
    editable<-ctx$workspace_state=="active"&&ctx$config$config_id==latest
    questions<-if(is.null(local$request))list() else
      Filter(function(q)q$resource_id==ctx$resource_id,local$request$questions)
    shiny::tagList(
      shiny::h2("Information to clarify"),
      shiny::p("Different datasets may require different information. Each question explains which checks depend on the answer."),
      shiny::div(class="alert alert-info",
        "Suggestions are drafts. Only Approve and save applies an answer in a new revision. Independent checks remain available; no scientific checks are run here."),
      if(editable)shiny::actionButton(ns("clarify_load"),"Check missing information",class="btn-primary")
      else shiny::p("Historical or removed view: answers are read-only. Select the latest active revision to answer."),
      if(!is.null(local$request)&&!length(questions))shiny::p("No clarification is required for this file in the selected configuration."),
      if(length(questions))shiny::tagList(
        shiny::p(paste(length(questions),"questions for the selected file. A linkage issue does not block independent date checks.")),
        shiny::selectInput(ns("clarify_question"),"Required information",choices=stats::setNames(
          vapply(questions,function(q)q$question_id,character(1)),
          vapply(seq_along(questions),function(i)paste(i,clarification_label(questions[[i]]$type),questions[[i]]$member),character(1))))),
      shiny::uiOutput(ns("clarification_form")),
      shiny::h3("Approved answers in the selected revision"),
      shiny::div(class="table-scroll",shiny::tableOutput(ns("clarification_history"))))
  })
  output$clarification_form <- shiny::renderUI({
    q<-current_question()
    ctx<-current_context()
    if(ctx$workspace_state!="active")return(NULL)
    table<-find_prepared_table(local$request$preparation,q$table_id)
    choices<-if(is.null(table)||is.null(table$schema))character() else column_choices(table$schema)
    fields<-switch(q$type,
      parser=clarification_parser_fields(ns,ctx$config$parsers[[q$resource_id]]),
      archive_parser=shiny::tagList(
        clarification_parser_fields(ns,table$proposed_setting$parser),
        shiny::checkboxInput(ns("clarify_header"),"The first row contains column headers",value=table$proposed_setting$header)),
      archive_linkage={
        labels<-vapply(q$table_choices,function(t)t$member,character(1))
        values<-vapply(q$table_choices,function(t)t$table_id,character(1))
        shiny::tagList(
          shiny::p("Confirm both tables and the meaning of their keys. The name id does not prove a relationship; dataset_id may be needed to define the scope."),
          shiny::selectInput(ns("clarify_core_table"),"Main table",c("Select"="",stats::setNames(values,labels))),
          shiny::selectInput(ns("clarify_extension_table"),"Reference table",c("Select"="",stats::setNames(values,labels))),
          shiny::uiOutput(ns("archive_linkage_columns")))
      },
      date_mapping=shiny::tagList(
        shiny::textInput(ns("clarify_role"),"Date role (required)",placeholder="E.g. sampling_date or analysis_date"),
        shiny::radioButtons(ns("clarify_mode"),"Structure",c("Single field"="single","Separate components"="split"),inline=TRUE),
        shiny::conditionalPanel(sprintf("input['%s'] === 'single'",ns("clarify_mode")),
          shiny::selectInput(ns("clarify_value"),"Date field",c("Select a column"="",choices)),
          shiny::selectInput(ns("clarify_order"),"Documented order (optional)",c("Undocumented: preserve ambiguity"="","Day / month / year"="DMY","Month / day / year"="MDY","Year / month / day"="YMD"))),
        shiny::conditionalPanel(sprintf("input['%s'] === 'split'",ns("clarify_mode")),
          shiny::selectInput(ns("clarify_day"),"Day column",c("Select"="",choices)),
          shiny::selectInput(ns("clarify_month"),"Month column",c("Select"="",choices)),
          shiny::selectInput(ns("clarify_year"),"Year column",c("Select"="",choices)))),
      linkage_mapping={
        core<-find_prepared_table(local$request$preparation,q$core_table_id)
        shiny::tagList(shiny::p("Specify the core key and the extension reference. occurrenceID does not automatically replace id."),
          shiny::selectInput(ns("clarify_core"),"Core key",c("Select"="",column_choices(core$schema))),
          shiny::selectInput(ns("clarify_reference"),"Extension reference",c("Select"="",choices)))
      },
      source_repair=shiny::tagList(
        shiny::p("Upload a new version with the corrected file or descriptor using Add data. Registered originals remain immutable."),
        shiny::textAreaInput(ns("clarify_note"),"Information from the data owner / required action",rows=3)))
    shiny::tagList(
      shiny::div(class="alert alert-warning",shiny::strong(clarification_label(q$type)),
        if(!is.null(q$member))shiny::p(paste("Table:",q$member)),
        shiny::p(q$reason),shiny::p(paste("Dependent checks:",paste(unlist(q$dependent_checks),collapse=", "))),
        if(q$status=="awaiting_source")shiny::p("Answer recorded; awaiting a usable source. The check remains not evaluated.")),
      if(length(q$suggestions))shiny::tags$details(open=NA,
        shiny::tags$summary("Unapproved suggestion"),
        shiny::p(clarification_suggestion_text(q)),
        shiny::actionButton(ns("clarify_suggest"),"Use as draft (does not save)")),
      fields,
      shiny::textAreaInput(ns("clarify_evidence"),"Reason / evidence for the answer (required)",rows=2),
      shiny::actionButton(ns("clarify_review"),"Review answer",class="btn-primary"))
  })
  output$archive_linkage_columns<-shiny::renderUI({
    q<-current_question();shiny::req(q$type=="archive_linkage",input$clarify_core_table,input$clarify_extension_table)
    core<-find_prepared_table(local$request$preparation,input$clarify_core_table)
    ext<-find_prepared_table(local$request$preparation,input$clarify_extension_table)
    shiny::req(!is.null(core),!is.null(ext),core$resource_id==q$resource_id,ext$resource_id==q$resource_id)
    hint<-local$link_suggestion
    core_selected<-if(!is.null(hint)&&identical(hint$core_table_id,core$table_id))hint$core_position else ""
    ext_selected<-if(!is.null(hint)&&identical(hint$extension_table_id,ext$table_id))hint$extension_position else ""
    shiny::tagList(
      shiny::selectInput(ns("clarify_core"),"Main table key",c("Select"="",column_choices(core$schema)),selected=as.character(core_selected)),
      shiny::selectInput(ns("clarify_reference"),"Reference key",c("Select"="",column_choices(ext$schema)),selected=as.character(ext_selected)))
  })
  shiny::observeEvent(input$clarify_suggest,attempt(function() {
    check_form();q<-current_question()
    shiny::req(length(q$suggestions))
    suggestion<-q$suggestions[[1]]
    if(q$type%in%c("parser","archive_parser")) {
      values<-if(q$type=="archive_parser")suggestion$answer$parser else suggestion$answer
      if(q$type=="archive_parser")shiny::updateCheckboxInput(session,"clarify_header",value=suggestion$answer$header)
      for(pair in list(c("clarify_encoding","encoding"),c("clarify_delimiter","delimiter"),
        c("clarify_decimal","decimal_mark"),c("clarify_quote","quote")))
        shiny::updateSelectInput(session,pair[1],selected=values[[pair[2]]])
    } else if(q$type=="date_mapping") {
      columns<-suggestion$columns
      split<-length(columns)>1L
      shiny::updateRadioButtons(session,"clarify_mode",selected=if(split)"split" else "single")
      for(role in names(columns))shiny::updateSelectInput(session,
        paste0("clarify_",if(role=="value")"value" else role),selected=as.character(columns[[role]]$position))
      # No semantic date role or date order is guessed by accepting a field hint.
    } else if(q$type=="archive_linkage") {
      local$link_suggestion<-suggestion$answer
      shiny::updateSelectInput(session,"clarify_core_table",selected=suggestion$answer$core_table_id)
      shiny::updateSelectInput(session,"clarify_extension_table",selected=suggestion$answer$extension_table_id)
    } else if(q$type=="linkage_mapping") {
      answer<-suggestion$answer
      if(!is.null(answer$core_position))shiny::updateSelectInput(session,"clarify_core",selected=as.character(answer$core_position))
      if(!is.null(answer$extension_position))shiny::updateSelectInput(session,"clarify_reference",selected=as.character(answer$extension_position))
    }
    local$draft<-NULL
    tell("Suggestion copied to the draft. Complete the answer, review it and explicitly approve it.","info")
  }))
  shiny::observeEvent(input$clarify_review,attempt(function() {
    check_form();q<-current_question()
    position<-function(value) {
      if(is.null(value)||!grepl("^(0|[1-9][0-9]*)$",value))stop("Select a column")
      as.numeric(value)
    }
    answer<-switch(q$type,
      archive_parser=list(parser=list(encoding=input$clarify_encoding,delimiter=input$clarify_delimiter,
        decimal_mark=input$clarify_decimal,quote=input$clarify_quote),header=isTRUE(input$clarify_header)),
      archive_linkage=list(core_table_id=input$clarify_core_table,extension_table_id=input$clarify_extension_table,
        core_position=position(input$clarify_core),extension_position=position(input$clarify_reference)),
      parser=list(encoding=input$clarify_encoding,delimiter=input$clarify_delimiter,
        decimal_mark=input$clarify_decimal,quote=input$clarify_quote),
      date_mapping={
        split<-identical(input$clarify_mode,"split")
        columns<-if(split)c(day=position(input$clarify_day),month=position(input$clarify_month),year=position(input$clarify_year)) else c(value=position(input$clarify_value))
        order<-if(split||is.null(input$clarify_order)||!nzchar(input$clarify_order))NULL else input$clarify_order
        list(date_role=input$clarify_role,columns=columns,date_order=order,
          date_order_evidence=if(is.null(order))"" else input$clarify_evidence)
      },
      linkage_mapping=list(core_position=position(input$clarify_core),extension_position=position(input$clarify_reference)),
      source_repair=list(note=input$clarify_note))
    local$draft<-NULL
    local$draft<-preview_clarification_answer(repo,local$request,q$question_id,
      answer,input$clarify_evidence,input$actor)
    shiny::showModal(shiny::modalDialog(title="Approve this answer",
      shiny::p("Review the values: they will be saved in a new revision. Closing or cancelling applies nothing."),
      shiny::tags$pre(clarification_review_text(local$draft)),
      if(q$type=="source_repair")shiny::p("This note does not make the file readable or unblock dependent checks."),
      footer=shiny::tagList(shiny::actionButton(ns("clarify_cancel"),"Cancel"),
        shiny::actionButton(ns("clarify_approve"),"Approve and save new revision",class="btn-primary")),
      easyClose=FALSE,size="l"),session=session)
  }))
  shiny::observeEvent(input$clarify_cancel,{
    local$draft<-NULL;shiny::removeModal(session=session)
    tell("Draft cancelled. No answer applied.","info")
  })
  shiny::observeEvent(input$clarify_approve,attempt(function() {
    ctx<-check_form();draft<-local$draft
    if(is.null(draft))stop("No answer awaiting approval")
    if(!identical(input$actor,draft$actor_id))stop("The operator has changed: review the answer")
    if(!identical(ctx$config$config_id,draft$config_id)||
       !identical(ctx$resource_id,draft$question$resource_id))stop("Context changed: review the answer")
    saved<-approve_clarification_answer(repo,draft,TRUE)
    local$draft<-NULL;local$request<-NULL
    shiny::removeModal(session=session)
    refresh_configs(ctx$version_id,saved$config_id)
    state$source_tick<-state$source_tick+1L
    tell(paste("Answer approved in revision",saved$revision,
      ". Previous revisions remain available."))
  }))
  output$clarification_history <- shiny::renderTable({
    ctx<-current_context()
    receipts<-Filter(function(r)r$resource_id==ctx$resource_id,clarification_receipts(ctx$config))
    if(!length(receipts))return(data.frame(Information="No approved answers in this revision."))
    data.frame(Information=vapply(receipts,function(r)clarification_label(r$type),character(1)),
      Answer=vapply(receipts,function(r)clarification_receipt_text(r),character(1)),
      Operator=vapply(receipts,function(r)r$actor_id,character(1)),
      Approval=vapply(receipts,function(r)r$approved_at,character(1)),
      Evidence=vapply(receipts,function(r)r$evidence,character(1)),check.names=FALSE)
  },striped=TRUE,rownames=FALSE)
  list(state=local)
}

column_choices <- function(table)stats::setNames(as.character(seq_along(table$headers)-1L),
  vapply(seq_along(table$headers),function(i)paste0(i-1L," - ",table$headers[[i]]),character(1)))
clarification_label <- function(type)switch(type,parser="Reading format",
  date_mapping="Date role and fields",linkage_mapping="Relationship keys",
  archive_parser="ZIP table format and headers",archive_linkage="Relationship between ZIP tables",
  source_repair="Source or declaration requiring clarification")
clarification_suggestion_text <- function(q) {
  s<-q$suggestions[[1]]
  if(q$type=="date_mapping")paste(s$evidence,"Columns:",paste(vapply(s$columns,
    function(c)paste(c$position,c$original_header,sep=" - "),character(1)),collapse="; "),
    ". The role must be confirmed by the operator.")
  else s$evidence
}
clarification_review_text <- function(draft) {
  value<-draft$reviewed_answer
  answer<-if(draft$question$type=="date_mapping")list(role=value$date_role,
    columns=value$columns,order=value$date_order) else if(draft$question$type%in%c("linkage_mapping","archive_linkage"))
    list(main_table=value$core$table$member,core_key=value$core$column,
      reference_table=value$extension$table$member,extension_reference=value$extension$column) else value
  jsonlite::toJSON(list(file=draft$question$original_name,table=draft$question$member,
    information=clarification_label(draft$question$type),answer=answer,
    replacements_to_approve=draft$replacements,
    operator=draft$actor_id,evidence=draft$evidence),auto_unbox=TRUE,pretty=TRUE,null="null")
}

clarification_receipt_text <- function(receipt) {
  value<-receipt$applied_value
  if(receipt$type=="archive_parser")return(paste(receipt$question$member,value$parser$encoding,
    if(value$parser$delimiter=="\t")"tab" else value$parser$delimiter,if(value$header)"with headers" else "without headers"))
  if(receipt$type=="date_mapping")paste(value$date_role,
    paste(vapply(value$columns,function(c)paste(c$position,c$original_header,sep=" - "),character(1)),collapse="; "))
  else if(receipt$type%in%c("linkage_mapping","archive_linkage"))paste("Core",value$core$column$position,
    value$core$column$original_header,"->",value$extension$column$position,value$extension$column$original_header)
  else if(receipt$type=="source_repair")value$note
  else paste(value$encoding,if(value$delimiter=="\t")"tab" else value$delimiter,
    "decimal mark",value$decimal_mark,"quote",value$quote)
}
clarification_parser_fields<-function(ns,parser)shiny::tagList(
  shiny::selectInput(ns("clarify_encoding"),"Encoding to confirm",c("UTF-8","windows-1252","latin1","UTF-16LE","UTF-16BE"),selected=parser$encoding),
  shiny::selectInput(ns("clarify_delimiter"),"Delimiter to confirm",c("Comma"=",","Semicolon"=";","Tab"="\t","Pipe"="|"),selected=parser$delimiter),
  shiny::selectInput(ns("clarify_decimal"),"Declared decimal mark",c("Dot"=".","Comma"=","),selected=parser$decimal_mark),
  shiny::selectInput(ns("clarify_quote"),"Text quoting",c("Double quotes"='"',"None"=""),selected=parser$quote))