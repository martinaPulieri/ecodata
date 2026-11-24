#' Create the local Shiny application
#'
#' Each session owns and closes its own SQLite connection. A supplied runtime
#' must be local and non-synchronised. Nothing is committed or uploaded to GitHub.
#' Construction sets the process-wide Shiny upload transport limit to 201 MiB;
#' registration independently enforces 50 MiB per file and 200 MiB in total.
#' @param runtime_root Persistent local runtime directory; NULL uses the default
#'   from open_repository(). Use a separate runtime for demos and real work.
#' @return A shiny.appobj for shiny::runApp().
#' @export
run_app <- function(runtime_root = NULL) {
  options(shiny.maxRequestSize = 201 * 1024^2)
  shiny::shinyApp(ui = workspace_ui(), server = function(input, output, session) {
    repo <- if (is.null(runtime_root)) open_repository() else open_repository(runtime_root)
    session$onSessionEnded(function() close_repository(repo))
    workspace_server("workspace", repo)
  })
}
