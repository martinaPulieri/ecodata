#' Connect the input workspace to its repository
#'
#' Each app session passes its own open connection. The module never closes a
#' caller-owned connection. Forms bind version/resource/configuration IDs and a
#' context token; server guards also reject historical or stale revision writes.
#' @param id Shiny module namespace.
#' @param repo Open, session-owned repository handle.
#' @return List of reactive context/inspection accessors for app composition.
#' @export
workspace_server <- function(id, repo) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    state <- shiny::reactiveValues(source_tick = 0L, history_tick = 0L,
      preferred_version = NULL, registered_upload = NULL, inspection = NULL,
      inspection_operation = NULL, notice = NULL, notice_kind = "info")
    tell <- function(text, kind = "success") { state$notice <- text; state$notice_kind <- kind }
    attempt <- function(fn) tryCatch(fn(), error = function(e) tell(paste("Operation not completed:", conditionMessage(e)), "danger"))
    lifecycle <- workspace_lifecycle(input, output, session, repo, state, tell, attempt)
    refresh_configs <- function(version, selected = NULL) {
      if (!is.null(selected)) state$config_preference <- selected
      rows <- list_configurations(repo, version)
      choices <- if (nrow(rows)) stats::setNames(rev(rows$config_id), paste0("Revision ", rev(rows$revision), " - ", rev(rows$actor_id))) else character()
      if (is.null(selected) && length(choices)) selected <- choices[[1]]
      shiny::updateSelectInput(session, "config", choices = choices, selected = selected)
    }
    shiny::observeEvent(lifecycle$configurations(), {
      rows <- lifecycle$configurations()
      if (is.null(rows)) return()
      choices <- if (nrow(rows)) stats::setNames(rev(rows$config_id), paste0("Revision ", rev(rows$revision), " - ", rev(rows$actor_id))) else character()
      selected <- shiny::isolate(input$config)
      preferred <- shiny::isolate(state$config_preference)
      if (!is.null(preferred) && preferred %in% choices) selected <- preferred
      if (is.null(selected) || !selected %in% choices) selected <- if (length(choices)) choices[[1]] else character()
      shiny::updateSelectInput(session, "config", choices = choices, selected = selected)
      state$config_preference <- NULL
    }, ignoreNULL = FALSE)
    shiny::observe({
      lifecycle$snapshot()
      choices <- workspace_version_choices(repo, lifecycle$view())
      selected <- shiny::isolate(input$version)
      preferred <- shiny::isolate(state$preferred_version)
      use_preferred <- !is.null(preferred) && preferred %in% choices
      if (use_preferred) selected <- preferred
      if (is.null(selected) || !selected %in% choices) selected <- if (length(choices)) choices[[1]] else character()
      shiny::updateSelectInput(session, "version", choices = choices, selected = selected)
      if (use_preferred) state$preferred_version <- NULL
    })
    shiny::observeEvent(input$version, {
      if (is.null(input$version) || !nzchar(input$version)) {
        shiny::updateSelectInput(session, "resource", choices = character())
        shiny::updateSelectInput(session, "config", choices = character())
        return()
      }
      resources <- get_input(repo, input$version)$resources
      choices <- stats::setNames(resources$resource_id, paste0(resources$original_name, " - ", substr(resources$resource_id, nchar(resources$resource_id) - 5, nchar(resources$resource_id))))
      shiny::updateSelectInput(session, "resource", choices = choices, selected = resources$resource_id[1])
      refresh_configs(input$version)
    }, ignoreNULL = FALSE)
    current_context <- shiny::reactive({
      lifecycle$selected()
      shiny::req(input$version, input$resource, input$config)
      manifest <- get_input(repo, input$version)
      config <- get_configuration(repo, input$config)
      shiny::req(config$version_id == input$version, input$resource %in% manifest$resources$resource_id)
      membership <- get_workspace_state(repo, input$version)
      list(version_id = input$version, resource_id = input$resource, config = config,
        workspace_state = membership$state, workspace_revision = membership$revision,
        resource = manifest$resources[manifest$resources$resource_id == input$resource, , drop = FALSE],
        token = hash_text(paste(input$version, input$resource, input$config, membership$revision, sep = ":")))
    })
    check_form <- function() {
      if (lifecycle$view() != "active" || !nrow(lifecycle$selected())) stop("The active context has changed. Reload and try again.")
      ctx <- current_context()
      if (!identical(lifecycle$selected()$version_id, ctx$version_id)) stop("The active context has changed")
      if (is.null(input$form_context) || !identical(input$form_context, ctx$token)) stop("The form context has changed. Wait for it to load and try again.")
      assert_workspace_active(repo, ctx$version_id, ctx$workspace_revision)
      ctx
    }
    shiny::observeEvent(list(input$version, input$resource, input$config), {
      preview <- state$preview_context
      if(!is.null(preview)&&identical(input$version,preview$version)&&
         identical(input$resource,preview$resource)&&identical(input$config,preview$config))return()
      state$inspection <- NULL
      state$inspection_operation <- NULL
    }, ignoreNULL = FALSE)
    shiny::observeEvent(lifecycle$selected(), {
      selected<-lifecycle$selected()
      if(nrow(selected)==1L&&identical(selected$workspace_state,"active")&&
         !is.null(state$preview_context)&&identical(selected$version_id,state$preview_context$version))return()
      state$inspection <- NULL
      state$inspection_operation <- NULL
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$register, attempt(function() {
      if (is.null(input$upload)) stop("Select at least one file")
      signature <- hash_text(json_text(as.list(input$upload)))
      if (identical(signature, state$registered_upload)) { tell("These files are already registered. Choose a new upload to register them again.", "info"); return() }
      result <- register_uploaded_inputs(repo, input$upload, input$title, input$actor)
      shiny::updateRadioButtons(session, "workspace_filter", selected = "active")
      state$registered_upload <- signature
      state$preferred_version <- result$version_id
      state$source_tick <- state$source_tick + 1L
      shiny::updateTabsetPanel(session,"view",selected="config")
      tell("Inputs registered. Original files are preserved; you can configure how they are read.")
    }))
    shiny::observeEvent(input$refresh, {
      state$source_tick <- state$source_tick + 1L
      state$history_tick <- state$history_tick + 1L
      if (!is.null(input$version) && nzchar(input$version)) refresh_configs(input$version)
    })
    shiny::observeEvent(input$init_config, attempt(function() {
      shiny::req(input$version)
      row <- lifecycle$selected()
      if (lifecycle$view() != "active" || nrow(row) != 1L || !identical(input$version, row$version_id)) stop("Select an active version")
      check_workspace_click(input$init_config, row$version_id, row$workspace_revision)
      cfg <- save_configuration(repo, row$version_id, actor_id = input$actor, expected_workspace_revision = input$init_config$revision)
      refresh_configs(input$version, cfg$config_id)
      tell("Initial configuration saved.")
    }))
    shiny::observeEvent(input$save, attempt(function() {
      ctx <- check_form()
      revisions <- list_configurations(repo, ctx$version_id)
      if (ctx$config$config_id != utils::tail(revisions$config_id, 1)) stop("The selected revision is historical: select the latest revision before saving.")
      parsers <- ctx$config$parsers
      archive<-tolower(tools::file_ext(ctx$resource$original_name))=="zip"
      if(!archive)parsers[[ctx$resource_id]] <- list(delimiter = input$delimiter, encoding = input$encoding,
        decimal_mark = input$decimal_mark, quote = input$quote)
      receipts<-clarification_receipts(ctx$config)
      if(!archive)receipts<-c(receipts,list(list(contract_version="clarification-answer-1.0",
        question_id=new_id(repo,"reading_confirmation"),question_key=paste("parser",ctx$resource_id,"settings",sep=":"),
        type="parser",version_id=ctx$version_id,base_config_id=ctx$config$config_id,resource_id=ctx$resource_id,
        source_sha256=ctx$resource$sha256,answer=parsers[[ctx$resource_id]],applied_value=parsers[[ctx$resource_id]],
        approved=TRUE,actor_id=input$actor,evidence="Reading settings confirmed with Save and generate preview",approved_at=utc_now())))
      state$inspection<-NULL;state$inspection_operation<-NULL
      saved <- save_configuration(repo, ctx$version_id, parsers = parsers, metadata = ctx$config$metadata,
        schema = ctx$config$schema, parser_detection = if (is.null(ctx$config$parser_detection)) list() else ctx$config$parser_detection,
        expected_revision = ctx$config$revision, actor_id = input$actor, expected_workspace_revision = ctx$workspace_revision,
        clarifications=receipts)
      state$preview_context<-list(version=ctx$version_id,resource=ctx$resource_id,config=saved$config_id)
      refresh_configs(ctx$version_id, saved$config_id)
      state$source_tick <- state$source_tick + 1L
      on.exit({state$history_tick<-state$history_tick+1L},add=TRUE)
      result<-run_workspace_inspection(repo,ctx$version_id,saved$config_id,input$actor,ctx$workspace_revision)
      state$inspection<-result$inspection;state$inspection_operation<-result$operation_id
      tell(paste("Revision", saved$revision, "saved and preview generated. Review the preview, then select Next."))
    }))
    shiny::observeEvent(input$detect, attempt(function() {
      ctx <- check_form()
      saved <- redetect_configuration(repo, ctx$config$config_id, ctx$resource_id, input$actor, ctx$workspace_revision)
      refresh_configs(ctx$version_id, saved$config_id)
      state$source_tick <- state$source_tick + 1L
      tell(paste("Detection saved in revision", saved$revision, "- review any warnings."))
    }))
    shiny::observeEvent(input$inspect, attempt(function() {
      ctx <- check_form()
      # A rerun cannot keep presenting a prior success if the new attempt fails.
      state$inspection <- NULL
      state$inspection_operation <- NULL
      on.exit({ state$history_tick <- state$history_tick + 1L }, add = TRUE)
      result <- run_workspace_inspection(repo, ctx$version_id, ctx$config$config_id, input$actor, ctx$workspace_revision)
      state$inspection <- result$inspection
      state$inspection_operation <- result$operation_id
      state$preview_context<-list(version=ctx$version_id,resource=ctx$resource_id,config=ctx$config$config_id)
      shiny::updateTabsetPanel(session, "view", selected = "config")
      tell("Preview generated and recorded in history. No scientific checks were run.")
    }))
    output$notice <- shiny::renderUI({
      if (!is.null(state$notice)) shiny::div(class = paste0("alert alert-", state$notice_kind), role = "status", state$notice)
    })
    output$metrics <- shiny::renderUI({
      state$source_tick; state$history_tick
      lifecycle$snapshot()
      versions <- list_workspace_inputs(repo)
      files <- if (nrow(versions)) sum(vapply(versions$version_id, function(id) nrow(get_input(repo, id)$resources), integer(1))) else 0L
      metric <- function(label, value, icon) shiny::div(class = "metric", shiny::div(shiny::span(class = "metric-label", label), shiny::strong(class = "metric-value", value)), shiny::span(class = "metric-symbol", shiny::icon(icon)))
      shiny::div(class = "metrics", metric("Active versions", nrow(versions), "layer-group"), metric("Active files", files, "file-lines"), metric("Recorded operations", nrow(lifecycle$operations()), "clock-rotate-left"))
    })
    output$resource_summary <- shiny::renderUI({
      if (!nrow(lifecycle$selected())) return(workspace_empty("No version selected", "Upload new files or select a version under Active or Removed."))
      if (is.null(input$version) || !nzchar(input$version) || is.null(input$resource) || !nzchar(input$resource)) return(workspace_empty("Start with your files", "Upload one or more files or select a registered version."))
      x <- get_input(repo, input$version)$resources
      x <- x[x$resource_id == input$resource, , drop = FALSE]
      shiny::req(nrow(x) == 1L)
      shiny::tagList(shiny::div(class = "file-title", shiny::span(class = "file-icon", shiny::icon("file-lines")),
        shiny::div(shiny::div(class = "file-name", x$original_name), shiny::div(class = "meta-line", paste(format(x$size_bytes, big.mark = " ", scientific = FALSE), "bytes - Registered original copy")))),
        shiny::span(class = "pill", paste("Acquisition:", x$acquisition_status)), shiny::span(class = "pill", "Original values preserved"),
        shiny::tags$details(class = "context-details", shiny::tags$summary("Identifiers and SHA-256 fingerprint"),
          shiny::p(shiny::tags$code(x$resource_id)), shiny::p(shiny::tags$code(x$sha256))))
    })
    output$parser_form <- shiny::renderUI({
      lifecycle$configurations()
      if (!nrow(lifecycle$selected())) return(NULL)
      shiny::req(input$version)
      membership <- get_workspace_state(repo, input$version)
      if (membership$state == "removed") {
        rows <- list_configurations(repo, input$version)
        details <- if (nrow(rows)) {
          ctx <- current_context()
          p <- ctx$config$parsers[[ctx$resource_id]]
          if (tolower(tools::file_ext(ctx$resource$original_name)) == "zip") shiny::p("ZIP archives with meta.xml use their descriptor. For other ZIP archives, review and approve each table's settings under Missing information.")
          else shiny::p(paste("Encoding:", p$encoding, "- Delimiter:", if (p$delimiter == "\t") "tab" else p$delimiter,
            "- Decimal mark:", p$decimal_mark, "- Text quoting:", p$quote))
        } else shiny::p("No configuration recorded.")
        return(shiny::tagList(shiny::div(class = "alert alert-info",
          "Removed version: read-only access. Configurations and history are preserved. Restore the version to generate previews or save changes."), details))
      }
      if (!nrow(list_configurations(repo, input$version))) return(shiny::tagList(shiny::p("No configuration available."),
        workspace_bound_button(ns, "init_config", "Create initial configuration", input$version, membership$revision)))
      ctx <- current_context()
      p <- ctx$config$parsers[[ctx$resource_id]]
      historical <- ctx$config$config_id != utils::tail(list_configurations(repo, ctx$version_id)$config_id, 1)
      archive <- tolower(tools::file_ext(ctx$resource$original_name)) == "zip"
      tabular <- tolower(tools::file_ext(ctx$resource$original_name)) %in% c("csv", "tsv")
      detection <- ctx$config$parser_detection[[ctx$resource_id]]
      fields <- if (archive) shiny::div(class = "alert alert-info", "ZIP archives with meta.xml use their descriptor. For other ZIP archives, review and approve each table's settings under Missing information.") else shiny::div(class = "parser-grid",
        shiny::selectInput(ns("delimiter"), "Delimiter", choices = c("Comma (,)" = ",", "Semicolon (;)" = ";", "Tab" = "\t", "Pipe (|)" = "|"), selected = p$delimiter),
        shiny::selectInput(ns("encoding"), "Encoding", choices = c("UTF-8", "windows-1252", "latin1", "UTF-16LE", "UTF-16BE"), selected = p$encoding),
        shiny::selectInput(ns("decimal_mark"), "Declared decimal mark", choices = c("Dot (.)" = ".", "Comma (,)" = ","), selected = p$decimal_mark),
        shiny::selectInput(ns("quote"), "Text quoting", choices = c("Double quotes" = '"', "None" = ""), selected = p$quote))
      shiny::tagList(shiny::div(style = "display:none", shiny::textInput(ns("form_context"), NULL, value = ctx$token)),
        if (historical) shiny::div(class = "alert alert-info", "You are viewing a historical revision. Changes cannot be saved from this view."),
        if (!is.null(detection) && !archive) detection_notice(detection, p),
        fields, shiny::p(class = "field-help", "Settings describe how the file is read. Numbers and dates remain text in the preview."),
        shiny::div(class = "action-row", if (!historical) shiny::actionButton(ns("save"), "Save and generate preview", icon = shiny::icon("floppy-disk"), class = "btn-primary"),
          if (!historical && tabular) shiny::actionButton(ns("detect"), "Detect format", icon = shiny::icon("wand-magic-sparkles"), class = "btn-outline-secondary"),
          if(historical)shiny::actionButton(ns("inspect"), "Preview saved revision", icon = shiny::icon("table"), class = "btn-outline-secondary")))
    })
    selected_preview <- shiny::reactive({
      shiny::req(state$inspection, input$resource)
      matches <- Filter(function(x) identical(x$resource_id, input$resource), state$inspection$resources)
      shiny::req(length(matches) == 1L)
      matches[[1]]
    })
    output$preview_summary <- shiny::renderUI({
      if (is.null(state$inspection)) return(workspace_empty("Preview", "Save the reading configuration to display a preview here."))
      x <- selected_preview()
      cfg <- get_configuration(repo, state$inspection$config_id)
      shiny::tagList(shiny::h2("Data as read"), shiny::span(class = "pill", paste("Revision", cfg$revision)),
        shiny::p(class = "muted", "Up to 20 rows per table. No numeric or date conversions."),
        if (x$status != "ready") shiny::div(class = "alert alert-warning", x$diagnostic),
        shiny::tags$details(class = "context-details", shiny::tags$summary("Preview context"), shiny::p(shiny::tags$code(state$inspection$config_id)), shiny::p(shiny::tags$code(state$inspection_operation))))
    })
    output$table_selector <- shiny::renderUI({
      x <- selected_preview()
      if (length(x$tables)) shiny::selectInput(ns("table"), "Table", choices = stats::setNames(seq_along(x$tables), vapply(x$tables, function(t) if (is.null(t$member)) "Main table" else t$member, character(1))))
    })
    output$preview_table <- shiny::renderTable({
      x <- selected_preview()
      shiny::req(length(x$tables) > 0L)
      index <- suppressWarnings(as.integer(input$table))
      if (length(index) != 1L || is.na(index) || index < 1L || index > length(x$tables)) index <- 1L
      x$tables[[index]]$preview
    }, striped = TRUE, bordered = FALSE, spacing = "s", rownames = FALSE)
    shiny::observe({
      state$history_tick
      rows <- lifecycle$operations()
      choices <- stats::setNames(rev(rows$operation_id), paste(rev(rows$created_at), rev(rows$status)))
      selected <- shiny::isolate(input$operation)
      if (is.null(selected) || !selected %in% choices) selected <- if (length(choices)) choices[[1]] else character()
      shiny::updateSelectInput(session, "operation", choices = choices, selected = selected)
    })
    output$history_table <- shiny::renderTable({
      state$history_tick
      rows <- lifecycle$operations()
      if (!nrow(rows)) return(data.frame(Information = "No preview or validation has been generated yet."))
      data.frame(Date = rev(rows$created_at), Activity = ifelse(rev(rows$operation_type)=="validation","Validation","Preview"), Status = rev(rows$status), check.names = FALSE)
    }, striped = TRUE, rownames = FALSE)
    output$operation_summary <- shiny::renderUI({
      shiny::req(input$operation)
      op <- get_operation(repo, input$operation)
      shiny::div(class = "context-details", shiny::p(paste("Revision", op$configuration$revision, "- Operator:", op$operation$actor_id)),
        shiny::p(shiny::tags$code(op$operation$version_id)), shiny::p(shiny::tags$code(op$operation$config_id)))
    })
    output$events_table <- shiny::renderTable({
      lifecycle$operations()
      shiny::req(input$operation)
      events <- get_operation(repo, input$operation)$events
      data.frame(Step = events$sequence, Status = events$status, Date = events$created_at, Operator = events$actor_id)
    }, striped = TRUE, rownames = FALSE)
    # Keep context tokens current while the operator uses another tab.
    shiny::outputOptions(output,"parser_form",suspendWhenHidden=FALSE)
    clarification <- workspace_clarifications(input,output,session,repo,current_context,
      check_form,state,refresh_configs,tell,attempt)
    validation <- workspace_validation(input,output,session,repo,current_context,state,tell,attempt)
    date_information <- workspace_date_information(input,output,session,repo,current_context,
      check_form,state,refresh_configs,tell,attempt)
    list(context = current_context, inspection = shiny::reactive(state$inspection),validation=validation)
  })
}

workspace_empty <- function(title, detail) shiny::div(class = "empty-state", shiny::icon("seedling"), shiny::h3(title), shiny::p(detail))

# Compare only detected components, not untouched decimal/quote conventions.
detection_notice <- function(detection, parser) {
  label <- function(separator) switch(separator, "," = "comma", ";" = "semicolon", "\t" = "tab", "|" = "pipe", "needs review")
  known_encoding <- identical(detection$encoding$status, "detected")
  known_delimiter <- identical(detection$delimiter$status, "detected")
  changed <- (known_encoding && parser$encoding != detection$parser$encoding) || (known_delimiter && parser$delimiter != detection$parser$delimiter)
  encoding <- if (known_encoding) detection$parser$encoding else "needs review"
  separator <- if (known_delimiter) label(detection$parser$delimiter) else "needs review"
  text <- paste0("Automatic detection: encoding ", encoding, "; delimiter ", separator, ".")
  if (changed) text <- paste(text, "The current configuration includes manual changes to the detected settings.")
  if (detection$status != "detected") text <- paste(text, "Incomplete or ambiguous evidence: review settings before generating a preview.")
  shiny::div(class = if (detection$status == "detected") "alert alert-info" else "alert alert-warning", text)
}
