# Polling refreshes views across sessions; repository guards remain authoritative.
workspace_lifecycle <- function(input, output, session, repo, state, tell, attempt) {
  ns <- session$ns
  changed <- shiny::reactivePoll(1500, session,
    checkFunc = function() DBI::dbGetQuery(repo$con, "PRAGMA data_version")[[1]],
    valueFunc = function() DBI::dbGetQuery(repo$con, "PRAGMA data_version")[[1]])
  snapshot <- shiny::reactiveVal(list_workspace_inputs(repo, "all"))
  configurations <- shiny::reactiveVal(NULL)
  operations <- shiny::reactiveVal(list_operations(repo))
  shiny::observe({
    changed(); state$source_tick
    snapshot(list_workspace_inputs(repo, "all"))
    if (!is.null(input$version) && nzchar(input$version)) configurations(list_configurations(repo, input$version))
    else configurations(NULL)
  })
  shiny::observe({ changed(); state$history_tick; operations(list_operations(repo)) })
  view <- shiny::reactive(if (identical(input$workspace_filter, "removed")) "removed" else "active")
  selected <- shiny::reactiveVal(data.frame())
  shiny::observe({
    rows <- snapshot()
    selected(rows[rows$version_id %in% input$version & rows$workspace_state == view(), , drop = FALSE])
  })
  refresh <- function() {
    state$inspection <- NULL; state$inspection_operation <- NULL
    state$source_tick <- state$source_tick + 1L
    state$history_tick <- state$history_tick + 1L
  }
  output$workspace_actions <- shiny::renderUI({
    row <- selected()
    if (!nrow(row)) return(NULL)
    if (view() == "removed") shiny::tagList(
      shiny::p(class = "field-help", "Original files and history are preserved. No disk space has been freed."),
      workspace_bound_button(ns, "restore", "Restore to workspace", row$version_id, row$workspace_revision))
    else shiny::tagList(
      shiny::p(class = "field-help", "This action applies to this version and all its files."),
      shiny::actionButton(ns("remove"), "Remove from workspace", icon = shiny::icon("box-archive"), class = "btn-outline-danger full-width"))
  })
  output$undo_removal <- shiny::renderUI({
    undo <- state$undo
    if (is.null(undo)) return(NULL)
    row <- snapshot()
    row <- row[row$version_id == undo$version_id, , drop = FALSE]
    if (!nrow(row) || row$workspace_state != "removed" || row$workspace_revision != undo$revision) return(NULL)
    shiny::div(class = "alert alert-info", role = "status", "Input removed. Original files and history are preserved. ",
      workspace_bound_button(ns, "undo_remove", "Undo removal", undo$version_id, undo$revision))
  })
  shiny::observeEvent(input$remove, attempt(function() {
    row <- selected()
    if (view() != "active" || nrow(row) != 1L || !identical(input$version, row$version_id) || row$workspace_state != "active") stop("Select an active version")
    manifest <- get_input(repo, row$version_id)
    request <- new_id(repo, "workspace_request")
    state$pending_removal <- list(version_id = row$version_id, revision = row$workspace_revision, request_id = request)
    title <- manifest$metadata$title
    if (is.null(title)) title <- manifest$resources$original_name[1]
    # Carry the token on the clicked button, so delayed clicks from an old
    # dialog cannot acquire the identity of a newly opened confirmation.
    confirm <- shiny::tags$button(type = "button", id = ns("confirm_remove_button"), class = "btn btn-danger",
      onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'});", ns("confirm_remove"), request), "Remove from workspace")
    cancel <- shiny::tags$button(type = "button", id = ns("cancel_remove_button"), class = "btn btn-outline-secondary",
      onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'});", ns("cancel_remove"), request), "Keep in workspace")
    shiny::showModal(shiny::modalDialog(title = "Remove from workspace?", easyClose = FALSE,
      shiny::strong(title), shiny::p(shiny::tags$code(row$version_id)),
      shiny::p(paste(nrow(manifest$resources), "files;", nrow(list_configurations(repo, row$version_id)), "configurations;",
        sum(list_operations(repo)$version_id == row$version_id), "operations preserved.")),
      shiny::tags$ul(lapply(manifest$resources$original_name, shiny::tags$li)),
      shiny::p("This version and all its files will leave the active list. Original files, configurations and history are preserved. You can restore them from Removed; no disk space is freed."),
      footer = shiny::tagList(cancel, confirm)))
  }))
  shiny::observeEvent(input$cancel_remove, {
    pending <- state$pending_removal
    if (!is.null(pending) && identical(input$cancel_remove, pending$request_id)) {
      state$pending_removal <- NULL
      shiny::removeModal()
    }
  })
  # Leaving a confirmation's source or view expires it permanently, even if
  # the user later returns to that source before a delayed click is delivered.
  shiny::observeEvent(list(input$version, view()), {
    pending <- state$pending_removal
    if (!is.null(pending) && (!identical(input$version, pending$version_id) || view() != "active")) {
      state$pending_removal <- NULL
      shiny::removeModal()
    }
  }, ignoreNULL = FALSE)
  shiny::observeEvent(input$confirm_remove, attempt(function() {
    pending <- state$pending_removal
    if (is.null(pending) || !identical(input$confirm_remove, pending$request_id) ||
        !identical(input$version, pending$version_id) || view() != "active") stop("The confirmation context has changed. Reopen the dialog.")
    on.exit({ state$pending_removal <- NULL; shiny::removeModal() }, add = TRUE)
    event <- set_workspace_state(repo, pending$version_id, "removed", pending$revision, pending$request_id, input$actor)
    state$undo <- list(version_id = event$version_id, revision = event$revision)
    refresh()
    tell("Version removed from the workspace. You can restore it from Removed.")
  }))
  restore <- function(version, revision) {
    set_workspace_state(repo, version, "active", revision, new_id(repo, "workspace_request"), input$actor)
    state$preferred_version <- version
    state$undo <- NULL
    shiny::updateRadioButtons(session, "workspace_filter", selected = "active")
    refresh()
    tell("Version restored. Configurations and history are unchanged.")
  }
  shiny::observeEvent(input$restore, attempt(function() {
    row <- selected()
    if (view() != "removed" || nrow(row) != 1L || !identical(input$version, row$version_id) || row$workspace_state != "removed") stop("Select a removed version")
    check_workspace_click(input$restore, row$version_id, row$workspace_revision)
    restore(row$version_id, row$workspace_revision)
  }))
  shiny::observeEvent(input$undo_remove, attempt(function() {
    undo <- state$undo
    if (is.null(undo)) stop("No removal to undo")
    check_workspace_click(input$undo_remove, undo$version_id, undo$revision)
    restore(undo$version_id, undo$revision)
  }))
  output$workspace_history <- shiny::renderTable({
    row <- selected()
    if (!nrow(row)) return(NULL)
    events <- list_workspace_events(repo, row$version_id)
    if (!nrow(events)) return(NULL)
    data.frame(Revision = events$revision, Status = ifelse(events$state == "removed", "Removed", "Restored"),
      Operator = events$actor_id, Date = events$created_at)
  }, striped = TRUE, rownames = FALSE)
  list(snapshot = snapshot, view = view, selected = selected,
    configurations = configurations, operations = operations)
}

# Each click carries the displayed source identity, not mutable browser inputs.
workspace_bound_button <- function(ns, id, label, version_id, revision) {
  shiny::tags$button(type = "button", id = ns(paste0(id, "_button")), class = "btn btn-outline-secondary full-width",
    onclick = paste0("Shiny.setInputValue(", json_text(ns(id)), ", ",
      json_text(list(version_id = version_id, revision = revision)), ", {priority:'event'});"), label)
}

check_workspace_click <- function(payload, version_id, revision) {
  if (!is.list(payload) || !identical(payload$version_id, version_id) ||
      is.null(payload$revision) || workspace_revision(payload$revision) != revision) stop("The button context has changed. Reload and try again.")
}
