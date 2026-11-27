# Approved date workflow. Background preparation never shares a SQLite handle.
workspace_date_information <- function(input,output,session,repo,current_context,
  check_form,state,refresh_configs,tell,attempt) {
  ns<-session$ns
  local<-shiny::reactiveValues(request=NULL,token=NULL,process=NULL,status="idle",
    error=NULL,request_id=NULL,submitted=FALSE,operation=NULL)
  format_id<-function(i,j)paste0("info_format_",i,"_",j,"_",substr(hash_text(local$request_id),1,10))
  stop_worker<-function(){p<-shiny::isolate(local$process);if(!is.null(p)&&p$is_alive())p$kill();local$process<-NULL}
  session$onSessionEnded(stop_worker)
  shiny::observeEvent(current_context()$token,{
    stop_worker();local$request<-NULL;local$status<-"idle";local$error<-NULL
    local$token<-current_context()$token;local$request_id<-new_id(repo,"date_workflow")
    local$submitted<-FALSE
  },ignoreInit=FALSE)
  tables<-shiny::reactive({shiny::req(local$request);ctx<-current_context()
    Filter(function(t)t$resource_id==ctx$resource_id,local$request$preparation$tables)})
  output$date_next<-shiny::renderUI({
    ctx<-current_context()
    latest<-utils::tail(list_configurations(repo,ctx$version_id)$config_id,1)
    ready<-!is.null(state$inspection)&&identical(state$inspection$config_id,ctx$config$config_id)
    shiny::div(class="workflow-bottom",validation_bound_button(ns,"date_next","Next",
      list(token=ctx$token),!ready||ctx$workspace_state!="active"||ctx$config$config_id!=latest||local$status=="checking"))
  })
  begin<-function(){
    ctx<-check_form()
    if(!identical(input$date_next$token,ctx$token))stop("The Next button context has changed")
    if(is.null(state$inspection)||!identical(state$inspection$config_id,ctx$config$config_id))stop("Save and generate the preview first")
    clarification_context(repo,list(contract_version="clarification-questions-1.0",version_id=ctx$version_id,
      config_id=ctx$config$config_id,config_hash=ctx$config$context_hash,workspace_revision=ctx$workspace_revision))
    stop_worker();local$request<-NULL;local$error<-NULL;local$status<-"checking";local$token<-ctx$token
    local$request_id<-new_id(repo,"date_workflow");local$submitted<-FALSE
    shiny::updateTabsetPanel(session,"view",selected="clarifications")
    session$onFlushed(function(){session$sendCustomMessage("ecodata-scroll",ns("date_information_panel"))},once=TRUE)
    local$process<-tryCatch(start_date_information_worker(repo,ctx),error=function(e){
      local$status<-"failed";local$error<-conditionMessage(e);stop(e)})
  }
  shiny::observeEvent(input$date_next,attempt(begin))
  poll<-function(){
    p<-local$process
    if(is.null(p)||p$is_alive())return(invisible(FALSE))
    local$process<-NULL
    result<-tryCatch(p$get_result(),error=identity)
    if(!identical(local$token,current_context()$token))return(invisible(FALSE))
    if(inherits(result,"error")){local$status<-"failed";local$error<-conditionMessage(result);return(invisible(FALSE))}
    local$request<-result;local$status<-"ready";invisible(TRUE)
  }
  shiny::observe({shiny::invalidateLater(300,session);current_context();shiny::isolate(poll())})
  output$date_information_panel<-shiny::renderUI({
    ctx<-current_context()
    content<-if(local$status=="checking")shiny::tagList(
      shiny::p(role="status","Checking missing information: reading tables and inspecting date formats..."),
      shiny::div(class="progress",role="progressbar",`aria-label`="Checking missing information",
        `aria-valuetext`="In progress; total duration is unknown",
        shiny::div(class="progress-bar progress-bar-striped progress-bar-animated active",style="width:100%"))) else
      if(local$status=="failed")shiny::div(class="alert alert-danger",role="alert",local$error,
        shiny::p("Return to Data and configuration, correct the reading settings and select Next again.")) else
      if(is.null(local$request))shiny::p("Save and generate a preview under Data and configuration, then select Next to check missing information.") else {
        ts<-tables()
        shiny::tagList(shiny::p(class="muted","Information check complete. Select date columns and confirm their formats."),
          shiny::h3("Required information"),shiny::tags$ul(class="date-requirements",lapply(seq_along(ts),function(i){
            t<-ts[[i]];label<-if(is.null(t$member))ctx$resource$original_name else t$member
            if(t$status!="complete")return(shiny::tags$li(shiny::strong(label),shiny::p(t$reason),
              shiny::p("Correct the source or reading settings. This table cannot be validated yet.")))
            saved<-Filter(function(m)identical(m$table$table_id,t$table_id)&&!is.null(m$declared_pattern),ctx$config$validation_spec$date_mappings)
            selected<-unlist(lapply(saved,function(m)if(length(m$columns)==1L)as.character(m$columns$value$position) else NULL),use.names=FALSE)
            split_saved<-Filter(function(m)length(m$columns)==3L,saved)
            shiny::tags$li(shiny::strong(label),
              shiny::selectInput(ns(paste0("info_structure_",i)),"Date structure",c("Single field(s)"="single","Separate day, month and year"="split"),
                selected=if(length(split_saved)&&!length(selected))"split" else "single"),
              shiny::conditionalPanel(sprintf("input['%s'] !== 'split'",ns(paste0("info_structure_",i))),
                shiny::selectInput(ns(paste0("info_fields_",i)),"Date field",c("Select column(s)"="",column_choices(t$schema)),selected=selected,multiple=TRUE)),
              shiny::uiOutput(ns(paste0("info_formats_",i))))
          })),
          if(length(Filter(function(q)q$type!="date_mapping"&&q$resource_id==ctx$resource_id,local$request$questions)))
            shiny::tags$details(shiny::tags$summary("Other reading or relationship information"),shiny::uiOutput(ns("clarification_panel"))),
          shiny::p(class="field-help","Only the date field and declared format are saved. Original values remain unchanged. Calendar validity is not assessed."))
      }
    shiny::tagList(shiny::h2("Missing information"),content)
  })
  shiny::observe({
    ctx<-current_context()
    if(is.null(local$request)||local$status!="ready") {
      session$sendCustomMessage("ecodata-date-run",list(id=ns("date_run_button"),visible=FALSE,disabled=TRUE,
        input=ns("date_run"),payload=list(token=ctx$token,request_id=local$request_id)))
      return()
    }
    ready<-FALSE;complete<-TRUE
    ts<-tables()
    for(i in seq_along(ts)) {
      if(ts[[i]]$status!="complete")next
      if(identical(input[[paste0("info_structure_",i)]],"split")) {
        values<-vapply(c("day","month","year"),function(role){v<-input[[paste0("info_",role,"_",i)]];if(is.null(v))"" else v},character(1))
        ready<-TRUE;complete<-complete&&all(nzchar(values))&&length(unique(values))==3L
      } else {
        fields<-input[[paste0("info_fields_",i)]];fields<-fields[nzchar(fields)]
        if(length(fields))ready<-TRUE
        for(j in fields){p<-input[[format_id(i,j)]];complete<-complete&&!is.null(p)&&nzchar(p)}
      }
    }
    session$sendCustomMessage("ecodata-date-run",list(id=ns("date_run_button"),visible=TRUE,
      disabled=!ready||!complete||local$submitted||ctx$workspace_state!="active",
      input=ns("date_run"),payload=list(token=ctx$token,request_id=local$request_id)))
  })
  # Register dependent format outputs once per prepared table. Format changes do
  # not recreate controls, so manual overrides survive ordinary reactive updates.
  shiny::observeEvent(local$request,{
    if(is.null(local$request))return()
    ts<-tables()
    for(i in seq_along(ts))local({
      index<-i;t<-ts[[i]]
      output[[paste0("info_formats_",index)]]<-shiny::renderUI({
        shiny::req(local$request)
        if(t$status!="complete")return(NULL)
        split_saved<-Filter(function(m)identical(m$table$table_id,t$table_id)&&length(m$columns)==3L,
          current_context()$config$validation_spec$date_mappings)
        if(identical(input[[paste0("info_structure_",index)]],"split"))return(shiny::tagList(
          lapply(c("day","month","year"),function(role)shiny::selectInput(ns(paste0("info_",role,"_",index)),
            paste0(toupper(substr(role,1,1)),substring(role,2)," field"),c("Select a column"="",column_choices(t$schema)),
            selected=if(length(split_saved))as.character(split_saved[[1]]$columns[[role]]$position) else "")),
          shiny::p("Declared format: separate numeric day/month/year components.")))
        fields<-input[[paste0("info_fields_",index)]]
        patterns<-date_patterns("date-patterns-1.1")$patterns
        ids<-names(Filter(function(p)p$kind!="split",patterns))
        shiny::tagList(lapply(fields[nzchar(fields)],function(position){
          j<-suppressWarnings(as.integer(position))
          if(is.na(j)||j<0L||j>=length(t$schema$headers))return(NULL)
          hint<-local$request$date_fields[[match(t$table_id,vapply(local$request$date_fields,`[[`,character(1),"table_id"))]]$fields[[j+1L]]
          saved<-Filter(function(m)identical(m$table$table_id,t$table_id)&&length(m$columns)==1L&&m$columns$value$position==j,
            current_context()$config$validation_spec$date_mappings)
          chosen<-if(length(saved)&&!is.null(saved[[1]]$declared_pattern))saved[[1]]$declared_pattern else hint$selected
          previous<-shiny::isolate(input[[format_id(index,j)]])
          if(!is.null(previous)&&previous%in%c("",ids))chosen<-previous
          shiny::tagList(shiny::selectInput(ns(format_id(index,j)),paste("Date format:",t$schema$headers[[j+1L]]),
            c("Choose a format"="",stats::setNames(ids,vapply(patterns[ids],`[[`,character(1),"format"))),selected=if(is.null(chosen))"" else chosen),
            shiny::p(class="field-help",if(is.null(hint$selected))hint$reason else
              paste("Detected format:",patterns[[hint$selected]]$format,".",hint$reason)),
            if(!is.null(hint$selected)&&identical(patterns[[hint$selected]]$timezone,"unspecified"))
              shiny::p(class="field-help","Timezone is not specified in the source. UTC is not assumed."),
            shiny::p(class="field-help",paste("Examples:",paste(unlist(hint$examples),collapse=" | "))))
        }))
      })
    })
  },ignoreNULL=TRUE)
  shiny::observeEvent(input$date_run,attempt(function(){
    ctx<-check_form();payload<-input$date_run
    if(local$submitted)return()
    if(local$status!="ready"||is.null(local$request)||!identical(payload$token,ctx$token)||
       !identical(payload$request_id,local$request_id))stop("Date information context has changed; select Next again")
    pending<-list_pending_operations(repo)
    if(any(pending$version_id==ctx$version_id & pending$operation_type=="validation"))stop("A validation run is already queued or running")
    ts<-tables();declarations<-list()
    for(i in seq_along(ts)) {
      t<-ts[[i]];if(t$status!="complete")next
      if(identical(input[[paste0("info_structure_",i)]],"split")) {
        cols<-vapply(c("day","month","year"),function(role){v<-input[[paste0("info_",role,"_",i)]]
          if(is.null(v)||!grepl("^(0|[1-9][0-9]*)$",v))stop("Select each day, month and year field")
          as.numeric(v)},numeric(1))
        declarations[[length(declarations)+1L]]<-list(table_id=t$table_id,columns=cols,pattern_id="split-numeric")
      } else for(position in input[[paste0("info_fields_",i)]]) {
        if(!nzchar(position))next
        if(!grepl("^(0|[1-9][0-9]*)$",position))stop("Select a date field")
        pattern<-input[[format_id(i,position)]]
        if(is.null(pattern)||!nzchar(pattern))stop("Choose a date format for every selected field")
        declarations[[length(declarations)+1L]]<-list(table_id=t$table_id,columns=c(value=as.numeric(position)),pattern_id=pattern)
      }
    }
    saved<-save_date_declarations(repo,local$request,declarations,input$actor,
      replace_table_ids=vapply(ts,`[[`,character(1),"table_id"))
    op<-submit_validation_run(repo,ctx$version_id,saved$config_id,input$actor,local$request_id,
      ctx$workspace_revision,families="dates")
    local$submitted<-TRUE;local$operation<-op$operation_id;state$validation_preferred<-op$operation_id
    refresh_configs(ctx$version_id,saved$config_id);state$source_tick<-state$source_tick+1L
    start_validation_worker(repo,op$operation_id);state$history_tick<-state$history_tick+1L
    shiny::updateTabsetPanel(session,"view",selected="validation")
    tell("Date declarations saved. Date validation is running against the declared formats.","info")
  }))
  list(local=local,poll=poll,format_id=format_id)
}
