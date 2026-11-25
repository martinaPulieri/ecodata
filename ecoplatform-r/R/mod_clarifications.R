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
    local$request<-shiny::withProgress(message="Verifica informazioni necessarie",value=0.2,
      prepare_clarifications(repo,ctx$version_id,ctx$config$config_id,ctx$workspace_revision))
    tell("Informazioni verificate. I suggerimenti attendono la tua approvazione.","info")
  }))

  output$clarification_panel <- shiny::renderUI({
    ctx<-current_context()
    latest<-utils::tail(list_configurations(repo,ctx$version_id)$config_id,1)
    editable<-ctx$workspace_state=="active"&&ctx$config$config_id==latest
    questions<-if(is.null(local$request))list() else
      Filter(function(q)q$resource_id==ctx$resource_id,local$request$questions)
    shiny::tagList(
      shiny::h2("Informazioni da chiarire"),
      shiny::p("Dataset diversi possono richiedere informazioni diverse. Ogni domanda spiega quali controlli dipendono dalla risposta."),
      shiny::div(class="alert alert-info",
        "I suggerimenti sono bozze. Solo Approva e salva applica la risposta in una nuova revisione. I controlli indipendenti restano disponibili; nessun controllo scientifico viene eseguito qui."),
      if(editable)shiny::actionButton(ns("clarify_load"),"Verifica informazioni mancanti",class="btn-primary")
      else shiny::p("Vista storica o rimossa: risposte in sola lettura. Seleziona la revisione attiva piu' recente per rispondere."),
      if(!is.null(local$request)&&!length(questions))shiny::p("Nessuna richiesta di chiarimento per questo file nella configurazione selezionata."),
      if(length(questions))shiny::tagList(
        shiny::p(paste(length(questions),"richieste per il file selezionato. Un problema del linkage non blocca le date indipendenti.")),
        shiny::selectInput(ns("clarify_question"),"Informazione richiesta",choices=stats::setNames(
          vapply(questions,function(q)q$question_id,character(1)),
          vapply(seq_along(questions),function(i)paste(i,clarification_label(questions[[i]]$type),questions[[i]]$member),character(1))))),
      shiny::uiOutput(ns("clarification_form")),
      shiny::h3("Risposte approvate nella revisione selezionata"),
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
        shiny::checkboxInput(ns("clarify_header"),"La prima riga contiene intestazioni",value=table$proposed_setting$header)),
      archive_linkage={
        labels<-vapply(q$table_choices,function(t)t$member,character(1))
        values<-vapply(q$table_choices,function(t)t$table_id,character(1))
        shiny::tagList(
          shiny::p("Conferma entrambe le tabelle e il significato delle chiavi. Il nome id non prova una relazione; dataset_id potrebbe essere necessario per lo scope."),
          shiny::selectInput(ns("clarify_core_table"),"Tabella principale",c("Seleziona"="",stats::setNames(values,labels))),
          shiny::selectInput(ns("clarify_extension_table"),"Tabella dei riferimenti",c("Seleziona"="",stats::setNames(values,labels))),
          shiny::uiOutput(ns("archive_linkage_columns")))
      },
      date_mapping=shiny::tagList(
        shiny::textInput(ns("clarify_role"),"Ruolo della data (richiesto)",placeholder="Es. sampling_date oppure analysis_date"),
        shiny::radioButtons(ns("clarify_mode"),"Struttura",c("Un campo"="single","Componenti separate"="split"),inline=TRUE),
        shiny::conditionalPanel(sprintf("input['%s'] === 'single'",ns("clarify_mode")),
          shiny::selectInput(ns("clarify_value"),"Campo data",c("Seleziona una colonna"="",choices)),
          shiny::selectInput(ns("clarify_order"),"Ordine documentato (facoltativo)",c("Non documentato: conserva ambiguita'"="","Giorno / mese / anno"="DMY","Mese / giorno / anno"="MDY","Anno / mese / giorno"="YMD"))),
        shiny::conditionalPanel(sprintf("input['%s'] === 'split'",ns("clarify_mode")),
          shiny::selectInput(ns("clarify_day"),"Colonna giorno",c("Seleziona"="",choices)),
          shiny::selectInput(ns("clarify_month"),"Colonna mese",c("Seleziona"="",choices)),
          shiny::selectInput(ns("clarify_year"),"Colonna anno",c("Seleziona"="",choices)))),
      linkage_mapping={
        core<-find_prepared_table(local$request$preparation,q$core_table_id)
        shiny::tagList(shiny::p("Indica la chiave del core e il riferimento dell'estensione. occurrenceID non sostituisce automaticamente id."),
          shiny::selectInput(ns("clarify_core"),"Chiave core",c("Seleziona"="",column_choices(core$schema))),
          shiny::selectInput(ns("clarify_reference"),"Riferimento estensione",c("Seleziona"="",choices)))
      },
      source_repair=shiny::tagList(
        shiny::p("Carica una nuova versione con il file/descrittore corretto tramite Aggiungi dati. Gli originali registrati restano immutabili."),
        shiny::textAreaInput(ns("clarify_note"),"Informazioni dal responsabile dei dati / azione necessaria",rows=3)))
    shiny::tagList(
      shiny::div(class="alert alert-warning",shiny::strong(clarification_label(q$type)),
        if(!is.null(q$member))shiny::p(paste("Tabella:",q$member)),
        shiny::p(q$reason),shiny::p(paste("Controlli dipendenti:",paste(unlist(q$dependent_checks),collapse=", "))),
        if(q$status=="awaiting_source")shiny::p("Risposta registrata; in attesa di una sorgente utilizzabile. Il controllo resta non valutato.")),
      if(length(q$suggestions))shiny::tags$details(open=NA,
        shiny::tags$summary("Suggerimento non approvato"),
        shiny::p(clarification_suggestion_text(q)),
        shiny::actionButton(ns("clarify_suggest"),"Usa come bozza (non salva)")),
      fields,
      shiny::textAreaInput(ns("clarify_evidence"),"Motivazione / evidenza della risposta (richiesta)",rows=2),
      shiny::actionButton(ns("clarify_review"),"Rivedi la risposta",class="btn-primary"))
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
      shiny::selectInput(ns("clarify_core"),"Chiave della tabella principale",c("Seleziona"="",column_choices(core$schema)),selected=as.character(core_selected)),
      shiny::selectInput(ns("clarify_reference"),"Chiave di riferimento",c("Seleziona"="",column_choices(ext$schema)),selected=as.character(ext_selected)))
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
    tell("Suggerimento copiato nella bozza. Completa la risposta, rivedila e approvala esplicitamente.","info")
  }))
  shiny::observeEvent(input$clarify_review,attempt(function() {
    check_form();q<-current_question()
    position<-function(value) {
      if(is.null(value)||!grepl("^(0|[1-9][0-9]*)$",value))stop("Seleziona una colonna")
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
    shiny::showModal(shiny::modalDialog(title="Approva questa risposta",
      shiny::p("Controlla i valori: verranno salvati in una nuova revisione. Chiudere o annullare non applica nulla."),
      shiny::tags$pre(clarification_review_text(local$draft)),
      if(q$type=="source_repair")shiny::p("Questa nota non rende il file leggibile e non sblocca i controlli dipendenti."),
      footer=shiny::tagList(shiny::actionButton(ns("clarify_cancel"),"Annulla"),
        shiny::actionButton(ns("clarify_approve"),"Approva e salva nuova revisione",class="btn-primary")),
      easyClose=FALSE,size="l"),session=session)
  }))
  shiny::observeEvent(input$clarify_cancel,{
    local$draft<-NULL;shiny::removeModal(session=session)
    tell("Bozza annullata. Nessuna risposta applicata.","info")
  })
  shiny::observeEvent(input$clarify_approve,attempt(function() {
    ctx<-check_form();draft<-local$draft
    if(is.null(draft))stop("Nessuna risposta in attesa di approvazione")
    if(!identical(input$actor,draft$actor_id))stop("L'operatore e' cambiato: rivedi la risposta")
    if(!identical(ctx$config$config_id,draft$config_id)||
       !identical(ctx$resource_id,draft$question$resource_id))stop("Contesto cambiato: rivedi la risposta")
    saved<-approve_clarification_answer(repo,draft,TRUE)
    local$draft<-NULL;local$request<-NULL
    shiny::removeModal(session=session)
    refresh_configs(ctx$version_id,saved$config_id)
    state$source_tick<-state$source_tick+1L
    tell(paste("Risposta approvata nella revisione",saved$revision,
      ". Le revisioni precedenti restano disponibili."))
  }))
  output$clarification_history <- shiny::renderTable({
    ctx<-current_context()
    receipts<-Filter(function(r)r$resource_id==ctx$resource_id,clarification_receipts(ctx$config))
    if(!length(receipts))return(data.frame(Informazione="Nessuna risposta approvata in questa revisione."))
    data.frame(Informazione=vapply(receipts,function(r)clarification_label(r$type),character(1)),
      Risposta=vapply(receipts,function(r)clarification_receipt_text(r),character(1)),
      Operatore=vapply(receipts,function(r)r$actor_id,character(1)),
      Approvazione=vapply(receipts,function(r)r$approved_at,character(1)),
      Evidenza=vapply(receipts,function(r)r$evidence,character(1)),check.names=FALSE)
  },striped=TRUE,rownames=FALSE)
  list(state=local)
}

column_choices <- function(table)stats::setNames(as.character(seq_along(table$headers)-1L),
  vapply(seq_along(table$headers),function(i)paste0(i-1L," - ",table$headers[[i]]),character(1)))
clarification_label <- function(type)switch(type,parser="Formato di lettura",
  date_mapping="Ruolo e campi data",linkage_mapping="Chiavi della relazione",
  archive_parser="Formato e intestazioni della tabella ZIP",archive_linkage="Relazione tra tabelle ZIP",
  source_repair="Sorgente o dichiarazione da integrare")
clarification_suggestion_text <- function(q) {
  s<-q$suggestions[[1]]
  if(q$type=="date_mapping")paste(s$evidence,"Colonne:",paste(vapply(s$columns,
    function(c)paste(c$position,c$original_header,sep=" - "),character(1)),collapse="; "),
    ". Il ruolo deve essere confermato dall'operatore.")
  else s$evidence
}
clarification_review_text <- function(draft) {
  value<-draft$reviewed_answer
  answer<-if(draft$question$type=="date_mapping")list(ruolo=value$date_role,
    colonne=value$columns,ordine=value$date_order) else if(draft$question$type%in%c("linkage_mapping","archive_linkage"))
    list(tabella_principale=value$core$table$member,chiave_core=value$core$column,
      tabella_riferimenti=value$extension$table$member,riferimento_estensione=value$extension$column) else value
  jsonlite::toJSON(list(file=draft$question$original_name,tabella=draft$question$member,
    informazione=clarification_label(draft$question$type),risposta=answer,
    sostituzioni_da_approvare=draft$replacements,
    operatore=draft$actor_id,evidenza=draft$evidence),auto_unbox=TRUE,pretty=TRUE,null="null")
}

clarification_receipt_text <- function(receipt) {
  value<-receipt$applied_value
  if(receipt$type=="archive_parser")return(paste(receipt$question$member,value$parser$encoding,
    if(value$parser$delimiter=="\t")"tabulazione" else value$parser$delimiter,if(value$header)"con intestazioni" else "senza intestazioni"))
  if(receipt$type=="date_mapping")paste(value$date_role,
    paste(vapply(value$columns,function(c)paste(c$position,c$original_header,sep=" - "),character(1)),collapse="; "))
  else if(receipt$type%in%c("linkage_mapping","archive_linkage"))paste("Core",value$core$column$position,
    value$core$column$original_header,"->",value$extension$column$position,value$extension$column$original_header)
  else if(receipt$type=="source_repair")value$note
  else paste(value$encoding,if(value$delimiter=="\t")"tabulazione" else value$delimiter,
    "decimale",value$decimal_mark,"quote",value$quote)
}
clarification_parser_fields<-function(ns,parser)shiny::tagList(
  shiny::selectInput(ns("clarify_encoding"),"Codifica da confermare",c("UTF-8","windows-1252","latin1","UTF-16LE","UTF-16BE"),selected=parser$encoding),
  shiny::selectInput(ns("clarify_delimiter"),"Separatore da confermare",c("Virgola"=",","Punto e virgola"=";","Tabulazione"="\t","Barra verticale"="|"),selected=parser$delimiter),
  shiny::selectInput(ns("clarify_decimal"),"Separatore decimale dichiarato",c("Punto"=".","Virgola"=","),selected=parser$decimal_mark),
  shiny::selectInput(ns("clarify_quote"),"Delimitazione testo",c("Doppi apici"='"',"Nessuna"=""),selected=parser$quote))