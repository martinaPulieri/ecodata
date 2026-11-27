# SQL-backed result browsing never rereads current input files or parser settings.
workspace_validation_results<-function(input,output,session,repo,current_context,local) {
  selected<-shiny::reactive({
    ctx<-current_context();local$runs
    id<-input$validation_result
    shiny::req(id,id%in%local$runs$operation_id)
    run<-get_validation_run(repo,id)
    shiny::req(run$frozen$version_id==ctx$version_id)
    run
  })
  summary<-shiny::reactive({run<-selected();local$active_run;get_validation_summary(repo,run$operation_id)})
  output$validation_summary<-shiny::renderUI({
    s<-summary();run<-s$run
    has_result<-nrow(DBI::dbGetQuery(repo$con,"SELECT operation_id FROM validation_results WHERE operation_id=?",params=list(run$operation_id)))>0L
    shiny::tagList(shiny::h3(validation_status_label(run$status)),
      shiny::p(paste("Saved revision",run$frozen$configuration$revision,"\u2014 Operator:",run$request$actor_id)),
      shiny::p("These are saved results for the run's exact configuration. Date recognition is not calendar validation; findings do not change original data."),
      if(!has_result)shiny::div(class="alert alert-info","No final results have been saved for this run.",utils::tail(run$events$reason,1)),
      if(has_result)shiny::tagList(
        shiny::div(class="validation-counts",validation_counts_table("Date classifications",s$date_counts),
          validation_counts_table("Linkage outcomes",s$linkage_counts)),
        if(nrow(s$findings))shiny::p(paste("Findings:",paste(paste(s$findings$severity,s$findings$count),collapse="; "))),
        shiny::h3("Coverage by mapped field or relationship"),
        shiny::tags$table(class="table table-striped validation-coverage",
          shiny::tags$thead(shiny::tags$tr(lapply(c("Check","Mapping","State","Population","Evaluated","Rows without saved classification","Explanation"),shiny::tags$th))),
          shiny::tags$tbody(lapply(s$mappings,function(m){
            population<-if(m$family=="dates")m$population_count else m$extension_population
            evaluated<-if(m$family=="dates")m$evaluated_rows else m$evaluated_measurements
            values<-list(validation_family_label(m$family),if(is.null(m$mapping_id))"Unresolved mapping" else m$mapping_id,
              validation_status_label(m$status),if(is.null(population))"Unknown" else population,evaluated,
              if(is.null(m$unclassified_rows))"Unknown" else m$unclassified_rows,m$reason)
            shiny::tags$tr(lapply(values,shiny::tags$td))
          })))),
      if(any(run$progress$status=="failed"))shiny::div(class="alert alert-warning",
        paste(run$progress$message[run$progress$status=="failed"],collapse="; ")))
  })
  shiny::observeEvent(input$validation_detail,{
    choices<-switch(input$validation_detail,
      dates=c("All statuses"="",Recognised="recognised",Ambiguous="ambiguous",Unrecognised="unrecognised",Missing="missing",Incomplete="incomplete","Not evaluated"="not_evaluated"),
      linkage=c("All outcomes"="",Linked="linked",Ambiguous="ambiguous","Missing reference"="missing_reference","Unresolved reference"="unresolved_reference","Not evaluated"="not_evaluated"),
      findings=c("All severities"="",Error="error",Warning="warning",Information="information"),c("All checks"=""))
    shiny::updateSelectInput(session,"validation_filter",choices=choices,selected="")
    shiny::updateNumericInput(session,"validation_page",value=1)
  })
  shiny::observeEvent(list(input$validation_result,input$validation_filter,input$validation_page_size),
    shiny::updateNumericInput(session,"validation_page",value=1),ignoreInit=TRUE)
  details<-shiny::reactive({
    run<-selected();local$active_run
    kind<-input$validation_detail
    if(is.null(kind)||!kind%in%c("dates","linkage","findings","checks"))kind<-"dates"
    page<-suppressWarnings(as.integer(input$validation_page));if(length(page)!=1L||is.na(page)||page<1L)page<-1L
    size<-suppressWarnings(as.integer(input$validation_page_size));if(length(size)!=1L||is.na(size)||!size%in%c(1L,25L,50L,100L))size<-25L
    filter<-input$validation_filter
    # Changing detail kind can leave a stale browser filter until its update
    # arrives. Ignore incompatible filters rather than silently hiding rows.
    allowed<-switch(kind,dates=c("recognised","ambiguous","unrecognised","missing","incomplete","not_evaluated"),
      linkage=c("linked","ambiguous","missing_reference","unresolved_reference","not_evaluated"),
      findings=c("error","warning","information"),character())
    if(is.null(filter)||!filter%in%allowed)filter<-NULL
    query_validation_details(repo,run$operation_id,kind,page,size,filter)
  })
  output$validation_page_info<-shiny::renderUI({
    d<-details();shiny::p(paste(d$total,"saved records matching this view. Page",d$page,"of",max(1,ceiling(d$total/d$page_size)),"\u2014",d$page_size,"rows per page."))
  })
  output$validation_details<-shiny::renderTable({
    d<-details();kind<-input$validation_detail
    if(!length(d$records))return(data.frame(Information="No saved records on this page. See coverage for unevaluated or unclassified populations."))
    rows<-lapply(d$records,function(r){
      if(kind=="findings")return(data.frame(Rule=r$rule_id,Severity=r$severity,Rows=paste(unlist(r$row_locators),collapse="; "),
        Original=paste(vapply(r$original_values,function(x)json_text(x),character(1)),collapse="; "),Explanation=r$reason,check.names=FALSE))
      if(kind=="checks")return(data.frame(Rule=r$rule_id,Applicability=r$applicability,State=r$execution_state,
        Population=if(is.null(r$population_count))"Unknown" else r$population_count,Evaluated=r$evaluated_count,Coverage=r$coverage,Explanation=r$reason,check.names=FALSE))
      if(kind=="linkage")return(data.frame(Table=r$mapping$extension$table$member,Mapping=r$mapping_id,Row=r$row_number,Outcome=r$outcome,Reference=json_text(r$original_reference),
        Targets=length(r$candidate_core_locators),"Candidate rows"=paste(unlist(r$candidate_core_locators),collapse="; "),check.names=FALSE))
      data.frame(Table=if(is.null(r$mapping$table$member))r$table_id else r$mapping$table$member,Mapping=r$mapping_id,Row=r$row_number,Role=r$date_role,Status=r$status,
        Fields=paste(vapply(r$mapping$columns,function(c)paste0(c$original_header," [",c$position,"]"),character(1)),collapse="; "),
        Original=paste(paste(names(r$original_values),vapply(r$original_values,function(x)json_text(x),character(1)),sep="="),collapse="; "),
        Patterns=paste(vapply(r$candidates,function(c)c$pattern$format,character(1)),collapse="; "),
        Widths=paste(paste(names(r$observed_widths),unlist(r$observed_widths),sep="="),collapse="; "),
        "Missing components"=paste(unlist(r$missing_components),collapse="; "),check.names=FALSE)
    })
    do.call(rbind,rows)
  },striped=TRUE,rownames=FALSE,spacing="s")
  output$validation_context<-shiny::renderText({
    run<-selected()
    paste("Source version:",run$frozen$version_id,"\nConfiguration:",run$frozen$config_id,
      "\nConfiguration hash:",run$frozen$config_hash,"\nFrozen request hash:",run$frozen_hash,
      "\nApplication code hash:",run$frozen$code_hash,
      "\nSource files:",paste(vapply(run$frozen$resources,function(r)paste(r$original_name,r$sha256),character(1)),collapse="\n"))
  })
  list(details=details,summary=summary)
}

validation_counts_table<-function(title,counts) {
  labels<-c(recognised="Recognised",ambiguous="Ambiguous",unrecognised="Unrecognised",missing="Missing",incomplete="Incomplete",not_evaluated="Not evaluated",
    linked="Uniquely linked",missing_reference="Missing reference",unresolved_reference="Unresolved reference")
  shiny::div(shiny::h3(title),shiny::tags$table(class="table table-sm",
    shiny::tags$tbody(lapply(names(counts),function(label)shiny::tags$tr(shiny::tags$th(labels[[label]]),shiny::tags$td(counts[[label]]))))))
}
