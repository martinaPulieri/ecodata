# Validation integration shares the workspace selection, but owns its exact
# submission token and result selection. No table scanning occurs in Run handlers.
workspace_validation <- function(input,output,session,repo,current_context,state,tell,attempt) {
  ns<-session$ns
  local<-shiny::reactiveValues(form=NULL,submitted_key=NULL,active_operation=NULL,runs=data.frame(),active_run=NULL,legacy=data.frame(),select_state=NULL)
  shiny::observeEvent(current_context()$token,{
    ctx<-current_context()
    local$form<-list(token=ctx$token,request_id=new_id(repo,"validation_request"))
    local$submitted_key<-NULL;local$active_operation<-NULL;local$active_run<-NULL
  },ignoreInit=FALSE)
  refresh<-function(){
    refresh_validation_workers(repo)
    ctx<-current_context()
    rows<-list_validation_runs(repo,ctx$version_id)
    local$runs<-rows
    pending<-rows$operation_id[rows$status%in%c("queued","running")]
    active<-if(length(pending))pending[1] else if(nrow(rows))rows$operation_id[1] else NULL
    intents<-list_pending_operations(repo)
    local$legacy<-intents[intents$version_id==ctx$version_id & intents$operation_type=="validation" & !intents$operation_id%in%rows$operation_id,,drop=FALSE]
    local$active_operation<-active
    local$active_run<-if(is.null(active))NULL else get_validation_run(repo,active)
    submitted<-shiny::isolate(local$submitted_key)
    if(!is.null(submitted)&&!is.null(shiny::isolate(local$active_run))&&
       !shiny::isolate(local$active_run$status)%in%c("queued","running")) {
      local$form<-list(token=ctx$token,request_id=new_id(repo,"validation_request"));local$submitted_key<-NULL
    }
    choices<-if(nrow(rows))stats::setNames(rows$operation_id,paste(rows$created_at,validation_status_label(rows$status),sep=" \u2014 ")) else character()
    chosen<-shiny::isolate(input$validation_result)
    preferred<-shiny::isolate(state$validation_preferred)
    if(!is.null(preferred)&&preferred%in%rows$operation_id)chosen<-preferred
    if(is.null(chosen)||!chosen%in%rows$operation_id)chosen<-if(nrow(rows))rows$operation_id[1] else character()
    select_state<-list(choices=choices,selected=chosen)
    if(!identical(select_state,shiny::isolate(local$select_state))) {
      shiny::updateSelectInput(session,"validation_result",choices=choices,selected=chosen)
      local$select_state<-select_state
    }
    if(!is.null(preferred)&&(identical(shiny::isolate(input$validation_result),preferred)||!preferred%in%rows$operation_id))state$validation_preferred<-NULL
  }
  shiny::observe({shiny::invalidateLater(800,session);current_context();shiny::isolate(refresh())})

  check_click<-function(payload){
    ctx<-current_context();form<-local$form
    if(!is.list(payload)||is.null(form)||!identical(payload$token,ctx$token)||
       !identical(payload$request_id,form$request_id))stop("The validation button context has changed. Reload and try again.")
    assert_workspace_active(repo,ctx$version_id,ctx$workspace_revision)
    ctx
  }
  shiny::observeEvent(input$validation_run,attempt(function(){
    ctx<-check_click(input$validation_run)
    if(nrow(local$legacy))stop("Cancel the legacy validation intent before starting a new run")
    pending<-list_validation_runs(repo,ctx$version_id)
    pending<-pending[pending$status%in%c("queued","running"),,drop=FALSE]
    if(nrow(pending)) {
      existing<-get_operation(repo,pending$operation_id[1])$operation$request_id
      if(existing!=input$validation_run$request_id)stop("A validation run for this version is already queued or running")
    }
    op<-submit_validation_run(repo,ctx$version_id,ctx$config$config_id,input$actor,
      input$validation_run$request_id,ctx$workspace_revision)
    local$submitted_key<-input$validation_run$request_id;local$active_operation<-op$operation_id
    state$validation_preferred<-op$operation_id
    start_validation_worker(repo,op$operation_id)
    state$history_tick<-state$history_tick+1L
    refresh()
    tell("Validation submitted. You can keep using the workspace while checks run.","info")
  }))
  shiny::observeEvent(input$validation_review,shiny::updateTabsetPanel(session,"view",selected="clarifications"))
  shiny::observeEvent(input$validation_legacy_cancel,attempt(function(){
    ctx<-current_context();payload<-input$validation_legacy_cancel
    if(!is.list(payload)||!identical(payload$token,ctx$token)||!payload$operation_id%in%local$legacy$operation_id)
      stop("The legacy validation context has changed")
    cancel_validation_run(repo,payload$operation_id,input$actor);refresh()
    state$history_tick<-state$history_tick+1L;tell("Legacy intent cancelled. Submit a new validation run with an exact snapshot.","info")
  }))
  check_run_action<-function(payload){
    ctx<-current_context();run<-local$active_run
    if(!is.list(payload)||is.null(run)||!identical(payload$operation_id,run$operation_id)||
      !identical(payload$token,ctx$token)||run$frozen$version_id!=ctx$version_id)stop("The validation run context has changed")
    run
  }
  shiny::observeEvent(input$validation_cancel,attempt(function(){
    run<-check_run_action(input$validation_cancel)
    updated<-cancel_validation_run(repo,run$operation_id,input$actor);refresh()
    state$history_tick<-state$history_tick+1L
    tell(if(updated$status%in%c("queued","running","cancelled"))"Cancellation requested. Partial scientific results will not be accepted." else
      "The run had already finished. Its saved results remain available.","info")
  }))
  shiny::observeEvent(input$validation_recover,attempt(function(){
    run<-check_run_action(input$validation_recover)
    recover_validation_run(repo,run$operation_id,input$actor);refresh()
    state$history_tick<-state$history_tick+1L;tell("Stopped worker recorded as interrupted. Submit a new run to retry.","info")
  }))
  output$validation_panel<-shiny::renderUI({
    ctx<-current_context();form<-local$form;run<-local$active_run
    pending<-!is.null(run)&&run$status%in%c("queued","running")
    legacy<-local$legacy
    shiny::tagList(shiny::h2("Run validation"),
      shiny::p(paste("Selected revision",ctx$config$revision,"\u2014 all files in this source version.")),
      shiny::p("Checks: exact occurrence\u2013measurement linkage and lexical date patterns. Each family reports its own coverage and limitations."),
      shiny::div(class="alert alert-info","Mappings require a usable descriptor or explicit approval. Review suggestions under Missing information. Recognised date patterns are not calendar-validity checks."),
      shiny::div(class="action-row",
        if(ctx$workspace_state=="active"&&!is.null(form))validation_bound_button(ns,"validation_run",
          if(pending)"Validation in progress" else "Run validation",list(token=ctx$token,request_id=form$request_id),pending||nrow(legacy)>0L,"btn-primary"),
        shiny::actionButton(ns("validation_review"),"Review mappings and missing information",class="btn-outline-secondary")),
      if(ctx$workspace_state!="active")shiny::p("Restore this version to run new validation. Saved results remain available under Results."),
      if(nrow(legacy))shiny::div(class="alert alert-warning",
        shiny::p("An older validation intent has no frozen request. Cancel it explicitly before submitting a new run; its history will be preserved."),
        lapply(legacy$operation_id,function(id)validation_bound_button(ns,"validation_legacy_cancel","Cancel legacy request",list(token=ctx$token,operation_id=id),FALSE,"btn-outline-secondary"))),
      if(!is.null(run))shiny::tagList(
        shiny::h3(validation_status_label(run$status)),
        validation_activity_indicator(run),
        shiny::p(paste("Run uses revision",run$frozen$configuration$revision,"and the exact source/configuration snapshot saved when submitted.")),
        if(run$cancel_requested&&pending)shiny::p("Cancellation requested; waiting for the worker to stop."),
        if(pending)shiny::div(class="action-row",
          validation_bound_button(ns,"validation_cancel","Cancel run",list(token=ctx$token,operation_id=run$operation_id),run$cancel_requested,"btn-outline-danger"),
          if(nrow(run$claim)&&!validation_claim_alive(run$claim))validation_bound_button(ns,"validation_recover","Recover stopped run",list(token=ctx$token,operation_id=run$operation_id),FALSE,"btn-outline-secondary")),
        if(run$status%in%c("failed","interrupted"))shiny::div(class="alert alert-warning",utils::tail(run$events$reason,1)),
        shiny::p("Completed describes execution. Findings and unevaluated rows still require interpretation.")))
  })
  output$validation_progress<-shiny::renderTable({
    run<-local$active_run
    if(is.null(run))return(NULL)
    p<-run$progress
    p<-p[!duplicated(p$family,fromLast=TRUE),,drop=FALSE]
    data.frame(Check=validation_family_label(p$family),State=validation_status_label(p$status),Detail=p$message)
  },striped=TRUE,rownames=FALSE)
  results<-workspace_validation_results(input,output,session,repo,current_context,local)
  list(local=local,refresh=refresh,details=results$details,summary=results$summary)
}

# Unknown duration: show real activity/stages rather than a fabricated percentage.
validation_activity_indicator<-function(run) {
  if(is.null(run)||!run$status%in%c("queued","running"))return(NULL)
  p<-run$progress
  p<-p[!duplicated(p$family,fromLast=TRUE),,drop=FALSE]
  stage<-if(nrow(p))paste(paste(validation_family_label(p$family),p$message,sep=": "),collapse="; ") else "Waiting for background worker"
  shiny::div(shiny::p(role="status",stage),
    shiny::div(class="progress",role="progressbar",`aria-label`="Validation progress",
      `aria-valuetext`=paste(validation_status_label(run$status),stage),
      shiny::div(class="progress-bar progress-bar-striped progress-bar-animated active",style="width:100%")))
}

validation_bound_button<-function(ns,id,label,payload,disabled=FALSE,class="btn-primary") {
  shiny::tags$button(type="button",id=ns(paste0(id,"_button")),class=paste("btn",class),
    disabled=if(disabled)"disabled" else NULL,
    onclick=paste0("Shiny.setInputValue(",json_text(ns(id)),",",json_text(payload),",{priority:'event'});"),label)
}

validation_status_label<-function(x) {
  labels<-c(queued="Queued",running="Running",completed="Completed",completed_with_limitations="Completed with limitations",
    failed="Technical failure",interrupted="Interrupted",cancelled="Cancelled",not_evaluated="Not evaluated",
    not_applicable="Not applicable",limited="Limited",unreadable="Unreadable")
  result<-unname(labels[x]); result[is.na(result)]<-x[is.na(result)];result
}
validation_family_label<-function(x) {
  labels<-c(linkage="Occurrence\u2013measurement linkage",dates="Date patterns",run="Run")
  result<-unname(labels[x]);result[is.na(result)]<-x[is.na(result)];result
}
