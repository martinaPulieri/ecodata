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
    attempt <- function(fn) tryCatch(fn(), error = function(e) tell(paste("Operazione non completata:", conditionMessage(e)), "danger"))
    refresh_configs <- function(version, selected = NULL) {
      rows <- list_configurations(repo, version)
      choices <- stats::setNames(rev(rows$config_id), paste0("Revisione ", rev(rows$revision), " - ", rev(rows$actor_id)))
      if (is.null(selected) && length(choices)) selected <- choices[[1]]
      shiny::updateSelectInput(session, "config", choices = choices, selected = selected)
    }
    shiny::observe({
      state$source_tick
      choices <- workspace_version_choices(repo)
      selected <- shiny::isolate(input$version)
      preferred <- shiny::isolate(state$preferred_version)
      if (!is.null(preferred)) selected <- preferred
      if (is.null(selected) || !selected %in% choices) selected <- if (length(choices)) choices[[1]] else character()
      shiny::updateSelectInput(session, "version", choices = choices, selected = selected)
      state$preferred_version <- NULL
    })
    shiny::observeEvent(input$version, {
      shiny::req(nzchar(input$version))
      resources <- get_input(repo, input$version)$resources
      choices <- stats::setNames(resources$resource_id, paste0(resources$original_name, " - ", substr(resources$resource_id, nchar(resources$resource_id) - 5, nchar(resources$resource_id))))
      shiny::updateSelectInput(session, "resource", choices = choices, selected = resources$resource_id[1])
      refresh_configs(input$version)
    })
    current_context <- shiny::reactive({
      shiny::req(input$version, input$resource, input$config)
      manifest <- get_input(repo, input$version)
      config <- get_configuration(repo, input$config)
      shiny::req(config$version_id == input$version, input$resource %in% manifest$resources$resource_id)
      list(version_id = input$version, resource_id = input$resource, config = config,
        resource = manifest$resources[manifest$resources$resource_id == input$resource, , drop = FALSE],
        token = hash_text(paste(input$version, input$resource, input$config, sep = ":")))
    })
    check_form <- function() {
      ctx <- current_context()
      if (is.null(input$form_context) || !identical(input$form_context, ctx$token)) stop("Il contesto del modulo e' cambiato. Attendi il caricamento e riprova.")
      ctx
    }
    shiny::observeEvent(list(input$version, input$resource, input$config), {
      state$inspection <- NULL
      state$inspection_operation <- NULL
    }, ignoreNULL = FALSE)
    shiny::observeEvent(input$register, attempt(function() {
      if (is.null(input$upload)) stop("Seleziona almeno un file")
      signature <- hash_text(json_text(as.list(input$upload)))
      if (identical(signature, state$registered_upload)) { tell("Questi file sono gia' registrati. Scegli un nuovo caricamento per registrarli di nuovo.", "info"); return() }
      result <- register_uploaded_inputs(repo, input$upload, input$title, input$actor)
      state$registered_upload <- signature
      state$preferred_version <- result$version_id
      state$source_tick <- state$source_tick + 1L
      tell("Input registrati. Gli originali sono conservati; puoi configurare la lettura.")
    }))
    shiny::observeEvent(input$refresh, {
      state$source_tick <- state$source_tick + 1L
      state$history_tick <- state$history_tick + 1L
      if (!is.null(input$version) && nzchar(input$version)) refresh_configs(input$version)
    })
    shiny::observeEvent(input$init_config, attempt(function() {
      shiny::req(input$version)
      cfg <- save_configuration(repo, input$version, actor_id = input$actor)
      refresh_configs(input$version, cfg$config_id)
      tell("Configurazione iniziale salvata.")
    }))
    shiny::observeEvent(input$save, attempt(function() {
      ctx <- check_form()
      revisions <- list_configurations(repo, ctx$version_id)
      if (ctx$config$config_id != utils::tail(revisions$config_id, 1)) stop("La revisione selezionata e' storica: seleziona la piu' recente prima di salvare.")
      if (tolower(tools::file_ext(ctx$resource$original_name)) == "zip") stop("Per gli archivi si usa il descrittore originale")
      parsers <- ctx$config$parsers
      parsers[[ctx$resource_id]] <- list(delimiter = input$delimiter, encoding = input$encoding,
        decimal_mark = input$decimal_mark, quote = input$quote)
      saved <- save_configuration(repo, ctx$version_id, parsers = parsers, metadata = ctx$config$metadata,
        schema = ctx$config$schema, parser_detection = if (is.null(ctx$config$parser_detection)) list() else ctx$config$parser_detection,
        expected_revision = ctx$config$revision, actor_id = input$actor)
      refresh_configs(ctx$version_id, saved$config_id)
      state$source_tick <- state$source_tick + 1L
      tell(paste("Revisione", saved$revision, "salvata. La precedente resta disponibile."))
    }))
    shiny::observeEvent(input$detect, attempt(function() {
      ctx <- check_form()
      saved <- redetect_configuration(repo, ctx$config$config_id, ctx$resource_id, input$actor)
      refresh_configs(ctx$version_id, saved$config_id)
      state$source_tick <- state$source_tick + 1L
      tell(paste("Rilevamento salvato nella revisione", saved$revision, "- verifica gli eventuali avvisi."))
    }))
    shiny::observeEvent(input$inspect, attempt(function() {
      ctx <- check_form()
      # A rerun cannot keep presenting a prior success if the new attempt fails.
      state$inspection <- NULL
      state$inspection_operation <- NULL
      on.exit({ state$history_tick <- state$history_tick + 1L }, add = TRUE)
      result <- run_workspace_inspection(repo, ctx$version_id, ctx$config$config_id, input$actor)
      state$inspection <- result$inspection
      state$inspection_operation <- result$operation_id
      shiny::updateTabsetPanel(session, "view", selected = "preview")
      tell("Anteprima generata e registrata nello storico. Nessun controllo scientifico eseguito.")
    }))
    output$notice <- shiny::renderUI({
      if (!is.null(state$notice)) shiny::div(class = paste0("alert alert-", state$notice_kind), role = "status", state$notice)
    })
    output$metrics <- shiny::renderUI({
      state$source_tick; state$history_tick
      versions <- list_inputs(repo)
      files <- if (nrow(versions)) sum(vapply(versions$version_id, function(id) nrow(get_input(repo, id)$resources), integer(1))) else 0L
      metric <- function(label, value, icon) shiny::div(class = "metric", shiny::div(shiny::span(class = "metric-label", label), shiny::strong(class = "metric-value", value)), shiny::span(class = "metric-symbol", shiny::icon(icon)))
      shiny::div(class = "metrics", metric("Versioni registrate", nrow(versions), "layer-group"), metric("File preservati", files, "file-lines"), metric("Operazioni tracciate", nrow(list_operations(repo)), "clock-rotate-left"))
    })
    output$resource_summary <- shiny::renderUI({
      if (is.null(input$version) || !nzchar(input$version) || is.null(input$resource) || !nzchar(input$resource)) return(workspace_empty("Il primo passo parte dai tuoi file", "Carica uno o piu' file oppure scegli una versione gia' registrata."))
      x <- get_input(repo, input$version)$resources
      x <- x[x$resource_id == input$resource, , drop = FALSE]
      shiny::req(nrow(x) == 1L)
      shiny::tagList(shiny::div(class = "file-title", shiny::span(class = "file-icon", shiny::icon("file-lines")),
        shiny::div(shiny::div(class = "file-name", x$original_name), shiny::div(class = "meta-line", paste(format(x$size_bytes, big.mark = " ", scientific = FALSE), "byte - Copia originale registrata")))),
        shiny::span(class = "pill", paste("Acquisizione:", x$acquisition_status)), shiny::span(class = "pill", "Valori originali preservati"),
        shiny::tags$details(class = "context-details", shiny::tags$summary("Identificatori e impronta SHA-256"),
          shiny::p(shiny::tags$code(x$resource_id)), shiny::p(shiny::tags$code(x$sha256))))
    })
    output$parser_form <- shiny::renderUI({
      shiny::req(input$version)
      if (!nrow(list_configurations(repo, input$version))) return(shiny::tagList(shiny::p("Nessuna configurazione disponibile."), shiny::actionButton(ns("init_config"), "Crea configurazione iniziale")))
      ctx <- current_context()
      p <- ctx$config$parsers[[ctx$resource_id]]
      historical <- ctx$config$config_id != utils::tail(list_configurations(repo, ctx$version_id)$config_id, 1)
      archive <- tolower(tools::file_ext(ctx$resource$original_name)) == "zip"
      tabular <- tolower(tools::file_ext(ctx$resource$original_name)) %in% c("csv", "tsv")
      detection <- ctx$config$parser_detection[[ctx$resource_id]]
      fields <- if (archive) shiny::div(class = "alert alert-info", "La lettura delle tabelle usa le impostazioni dichiarate nel meta.xml dell'archivio.") else shiny::div(class = "parser-grid",
        shiny::selectInput(ns("delimiter"), "Separatore", choices = c("Virgola (,)" = ",", "Punto e virgola (;)" = ";", "Tabulazione" = "\t", "Barra verticale (|)" = "|"), selected = p$delimiter),
        shiny::selectInput(ns("encoding"), "Codifica", choices = c("UTF-8", "windows-1252", "latin1", "UTF-16LE", "UTF-16BE"), selected = p$encoding),
        shiny::selectInput(ns("decimal_mark"), "Separatore decimale dichiarato", choices = c("Punto (.)" = ".", "Virgola (,)" = ","), selected = p$decimal_mark),
        shiny::selectInput(ns("quote"), "Delimitazione del testo", choices = c("Doppi apici" = '"', "Nessuna" = ""), selected = p$quote))
      shiny::tagList(shiny::div(style = "display:none", shiny::textInput(ns("form_context"), NULL, value = ctx$token)),
        if (historical) shiny::div(class = "alert alert-info", "Stai consultando una revisione storica. Le modifiche non verranno salvate da questa vista."),
        if (!is.null(detection) && !archive) detection_notice(detection, p),
        fields, shiny::p(class = "field-help", "Le impostazioni descrivono la lettura. Numeri e date restano testo nell'anteprima."),
        shiny::div(class = "action-row", if (!historical && !archive) shiny::actionButton(ns("save"), "Salva nuova revisione", icon = shiny::icon("floppy-disk"), class = "btn-primary"),
          if (!historical && tabular) shiny::actionButton(ns("detect"), "Rileva formato", icon = shiny::icon("wand-magic-sparkles"), class = "btn-outline-secondary"),
          shiny::actionButton(ns("inspect"), "Genera anteprima", icon = shiny::icon("table"), class = "btn-outline-secondary")))
    })
    selected_preview <- shiny::reactive({
      shiny::req(state$inspection, input$resource)
      matches <- Filter(function(x) identical(x$resource_id, input$resource), state$inspection$resources)
      shiny::req(length(matches) == 1L)
      matches[[1]]
    })
    output$preview_summary <- shiny::renderUI({
      if (is.null(state$inspection)) return(workspace_empty("Un'anteprima, con il suo contesto", "Seleziona una revisione e premi Genera anteprima nella scheda Dati e configurazione."))
      x <- selected_preview()
      cfg <- get_configuration(repo, state$inspection$config_id)
      shiny::tagList(shiny::h2("I dati, come sono stati letti"), shiny::span(class = "pill", paste("Revisione", cfg$revision)),
        shiny::p(class = "muted", "Fino a 20 righe per tabella. Nessuna conversione numerica o temporale."),
        if (x$status != "ready") shiny::div(class = "alert alert-warning", x$diagnostic),
        shiny::tags$details(class = "context-details", shiny::tags$summary("Contesto dell'anteprima"), shiny::p(shiny::tags$code(state$inspection$config_id)), shiny::p(shiny::tags$code(state$inspection_operation))))
    })
    output$table_selector <- shiny::renderUI({
      x <- selected_preview()
      if (length(x$tables)) shiny::selectInput(ns("table"), "Tabella", choices = stats::setNames(seq_along(x$tables), vapply(x$tables, function(t) if (is.null(t$member)) "Tabella principale" else t$member, character(1))))
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
      rows <- list_operations(repo)
      choices <- stats::setNames(rev(rows$operation_id), paste(rev(rows$created_at), rev(rows$status)))
      shiny::updateSelectInput(session, "operation", choices = choices, selected = if (length(choices)) choices[[1]] else character())
    })
    output$history_table <- shiny::renderTable({
      state$history_tick
      rows <- list_operations(repo)
      if (!nrow(rows)) return(data.frame(Informazione = "Nessuna anteprima ancora eseguita."))
      data.frame(Data = rev(rows$created_at), Attivita = "Anteprima", Stato = rev(rows$status), check.names = FALSE)
    }, striped = TRUE, rownames = FALSE)
    output$operation_summary <- shiny::renderUI({
      shiny::req(input$operation)
      op <- get_operation(repo, input$operation)
      shiny::div(class = "context-details", shiny::p(paste("Revisione", op$configuration$revision, "- Operatore:", op$operation$actor_id)),
        shiny::p(shiny::tags$code(op$operation$version_id)), shiny::p(shiny::tags$code(op$operation$config_id)))
    })
    output$events_table <- shiny::renderTable({
      shiny::req(input$operation)
      events <- get_operation(repo, input$operation)$events
      data.frame(Passo = events$sequence, Stato = events$status, Data = events$created_at, Operatore = events$actor_id)
    }, striped = TRUE, rownames = FALSE)
    list(context = current_context, inspection = shiny::reactive(state$inspection))
  })
}

workspace_empty <- function(title, detail) shiny::div(class = "empty-state", shiny::icon("seedling"), shiny::h3(title), shiny::p(detail))

# Compare only detected components, not untouched decimal/quote conventions.
detection_notice <- function(detection, parser) {
  label <- function(separator) switch(separator, "," = "virgola", ";" = "punto e virgola", "\t" = "tabulazione", "|" = "barra verticale", "da verificare")
  known_encoding <- identical(detection$encoding$status, "detected")
  known_delimiter <- identical(detection$delimiter$status, "detected")
  changed <- (known_encoding && parser$encoding != detection$parser$encoding) || (known_delimiter && parser$delimiter != detection$parser$delimiter)
  encoding <- if (known_encoding) detection$parser$encoding else "da verificare"
  separator <- if (known_delimiter) label(detection$parser$delimiter) else "da verificare"
  text <- paste0("Rilevamento automatico: codifica ", encoding, "; separatore ", separator, ".")
  if (changed) text <- paste(text, "La configurazione corrente contiene modifiche manuali rispetto al rilevamento.")
  if (detection$status != "detected") text <- paste(text, "Evidenza incompleta o ambigua: controlla le impostazioni prima dell'anteprima.")
  shiny::div(class = if (detection$status == "detected") "alert alert-info" else "alert alert-warning", text)
}
