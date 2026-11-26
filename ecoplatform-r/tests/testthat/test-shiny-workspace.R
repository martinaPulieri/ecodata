test_that("Shiny registration, explicit saves and inspection use the selected context", {
  repo <- new_test_repo()
  shiny::testServer(workspace_server, args = list(repo = repo), {
    path <- write_fixture("station;value\n001;1,5\n")
    upload <- data.frame(name = "sample.csv", size = file.info(path)$size, type = "text/csv", datapath = path)
    session$setInputs(actor = "reviewer", title = "Sample", upload = upload, register = 1)
    expect_equal(nrow(list_inputs(repo)), 1L)
    vid <- list_inputs(repo)$version_id
    rid <- get_input(repo, vid)$resources$resource_id
    cid <- list_configurations(repo, vid)$config_id
    session$setInputs(version = vid, resource = rid, config = cid)
    ctx <- current_context()
    session$setInputs(form_context = ctx$token, delimiter = ";", encoding = "UTF-8", decimal_mark = ",", quote = '"')
    expect_equal(nrow(list_configurations(repo, vid)), 1L)
    session$setInputs(save = 1)
    expect_equal(nrow(list_configurations(repo, vid)), 2L)
    newcid <- utils::tail(list_configurations(repo, vid)$config_id, 1)
    session$setInputs(config = newcid)
    ctx <- current_context()
    session$setInputs(form_context = ctx$token, inspect = 1)
    expect_equal(state$inspection$config_id, newcid)
    expect_identical(state$inspection$resources[[1]]$tables[[1]]$preview[[1]], "001")
    expect_match(output$preview_table, "001")
    expect_equal(nrow(list_operations(repo)), 1L)
    session$setInputs(config = cid)
    expect_equal(get_configuration(repo, cid)$parsers[[rid]]$delimiter, ";")
    expect_null(state$inspection)
    ctx <- current_context()
    session$setInputs(form_context = ctx$token, save = 2)
    expect_equal(nrow(list_configurations(repo, vid)), 2L)
    expect_match(state$notice, "historical")
  })
})

test_that("stale form events cannot change another file and repeat registration is guarded", {
  repo <- new_test_repo()
  shiny::testServer(workspace_server, args = list(repo = repo), {
    path <- write_fixture()
    upload <- data.frame(name = "one.csv", size = file.info(path)$size, type = "text/csv", datapath = path)
    session$setInputs(actor = "tester", title = "One", upload = upload, register = 1)
    session$setInputs(register = 2)
    expect_equal(nrow(list_inputs(repo)), 1L)
    vid <- list_inputs(repo)$version_id
    rid <- get_input(repo, vid)$resources$resource_id
    cid <- list_configurations(repo, vid)$config_id
    session$setInputs(version = vid, resource = rid, config = cid, form_context = "wrong", save = 1)
    expect_equal(nrow(list_configurations(repo, vid)), 1L)
    expect_match(state$notice, "context")
  })
})

test_that("unsupported and unreadable previews show limitations without table-index errors", {
  repo <- new_test_repo()
  for (case in list(list(text = "unsupported", suffix = ".pdf"), list(text = "a,b\n1,2,3\n", suffix = ".csv"))) {
    v <- register_input(write_fixture(case$text, case$suffix), list(), repo)
    cfg <- make_config(repo, v$version_id)
    rid <- get_input(repo, v$version_id)$resources$resource_id
    shiny::testServer(workspace_server, args = list(repo = repo), {
      session$setInputs(actor = "tester", version = v$version_id, resource = rid, config = cfg$config_id)
      session$setInputs(form_context = current_context()$token, inspect = 1)
      expect_equal(length(state$inspection$resources[[1]]$tables), 0L)
      expect_error(output$preview_table, class = "shiny.silent.error")
      expect_equal(list_operations(repo)$status[nrow(list_operations(repo))], "completed_with_limitations")
    })
  }
})

test_that("a failed rerun clears the old preview and refreshes rendered history", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  cfg <- make_config(repo, v$version_id)
  rid <- get_input(repo, v$version_id)$resources$resource_id
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(actor = "tester", version = v$version_id, resource = rid, config = cfg$config_id)
    session$setInputs(form_context = current_context()$token, inspect = 1)
    expect_false(is.null(state$inspection))
    expect_match(output$history_table, "completed") # force and cache the rendered output
    # Failure injection at the domain boundary; lifecycle writes still use real SQLite.
    testthat::with_mocked_bindings({
      session$setInputs(inspect = 2)
      expect_null(state$inspection)
      expect_match(output$history_table, "failed")
      expect_match(state$notice, "Injected inspection failure")
      expect_equal(utils::tail(list_operations(repo)$status, 1), "failed")
    }, inspect_input = function(...) stop("Injected inspection failure"), .package = "ecodata")
  })
})

test_that("public Shiny entry point configures the advertised upload transport limit", {
  withr::local_options(shiny.maxRequestSize = 5 * 1024^2)
  app <- run_app(tempfile("app-limit-"))
  expect_s3_class(app, "shiny.appobj")
  expect_gte(getOption("shiny.maxRequestSize"), 201 * 1024^2)
})

test_that("explicit detection in Shiny appends a revision without accepting a stale form", {
  repo <- new_test_repo()
  path <- tempfile(fileext = ".csv")
  bytes <- iconv("id\tvalue\n001\tNA\n", from = "UTF-8", to = "UTF-16LE", toRaw = TRUE)[[1]]
  writeBin(c(as.raw(c(255,254)), bytes), path)
  v <- register_input(path, list(), repo)
  first <- make_config(repo, v$version_id)
  rid <- get_input(repo, v$version_id)$resources$resource_id
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(actor = "tester", version = v$version_id, resource = rid, config = first$config_id)
    session$setInputs(form_context = current_context()$token, detect = 1)
    latest <- utils::tail(list_configurations(repo, v$version_id)$config_id, 1)
    expect_equal(get_configuration(repo, latest)$parsers[[rid]]$encoding, "UTF-16LE")
    expect_equal(get_configuration(repo, latest)$parsers[[rid]]$delimiter, "\t")
    expect_equal(nrow(list_operations(repo)), 0L)
    expect_equal(get_configuration(repo, first$config_id)$parsers[[rid]]$encoding, "UTF-8")
    session$setInputs(config = latest)
    expect_match(as.character(output$parser_form$html), "Automatic detection")
    session$setInputs(form_context = current_context()$token, inspect = 1)
    expect_match(output$preview_table, "001")
    session$setInputs(form_context = "stale", detect = 2)
    expect_equal(nrow(list_configurations(repo, v$version_id)), 2L)
    expect_match(state$notice, "context")
  })
})
