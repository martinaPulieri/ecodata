test_that("Shiny cancel, remove and undo preserve the input and clear its preview", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  cfg <- make_config(repo, v$version_id)
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(actor = "tester", version = v$version_id, resource = v$resource_ids[1], config = cfg$config_id)
    session$setInputs(form_context = current_context()$token, inspect = 1)
    expect_false(is.null(state$inspection))
    session$setInputs(remove = 1)
    expect_equal(state$pending_removal$version_id, v$version_id)
    session$setInputs(cancel_remove = state$pending_removal$request_id)
    expect_equal(get_workspace_state(repo, v$version_id)$state, "active")
    expect_null(state$pending_removal)
    session$setInputs(remove = 2)
    token <- state$pending_removal$request_id
    session$setInputs(confirm_remove = token)
    expect_equal(get_workspace_state(repo, v$version_id)$state, "removed")
    expect_null(state$inspection)
    expect_length(workspace_version_choices(repo), 0L)
    expect_match(output$history_table, "completed")
    session$setInputs(undo_remove = list(version_id = v$version_id, revision = 1L))
    expect_equal(get_workspace_state(repo, v$version_id)$state, "active")
    expect_true(verify_input(repo, v$version_id)$ok)
  })
})

test_that("old cancellation and selection round trips cannot confirm a newer dialog", {
  repo <- new_test_repo()
  a <- register_fixture(repo)
  b <- register_fixture(repo)
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(actor = "tester", version = a$version_id, remove = 1)
    first <- state$pending_removal$request_id
    session$setInputs(cancel_remove = first)
    session$setInputs(remove = 2)
    second <- state$pending_removal$request_id
    session$setInputs(cancel_remove = first)
    expect_equal(state$pending_removal$request_id, second)
    session$setInputs(version = b$version_id)
    session$setInputs(version = a$version_id, confirm_remove = second)
    expect_equal(get_workspace_state(repo, a$version_id)$state, "active")
  })
})

test_that("removed ZIP settings describe the archive member configuration", {
  repo <- new_test_repo()
  v <- register_input(write_fixture("unsupported archive", ".zip"), list(), repo)
  cfg <- make_config(repo, v$version_id)
  set_workspace_state(repo, v$version_id, "removed", 0L, "zip-remove", "tester")
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(workspace_filter = "removed", version = v$version_id, resource = v$resource_ids[1], config = cfg$config_id)
    expect_match(as.character(output$parser_form$html), "meta.xml")
  })
})

test_that("initial configuration buttons cannot survive a remove restore cycle", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(actor = "tester", version = v$version_id, resource = v$resource_ids[1])
    set_workspace_state(repo, v$version_id, "removed", 0L, "rm-no-config", "tester")
    set_workspace_state(repo, v$version_id, "active", 1L, "restore-no-config", "tester")
    session$setInputs(refresh = 1, init_config = list(version_id = v$version_id, revision = 0L))
    expect_equal(nrow(list_configurations(repo, v$version_id)), 0L)
    session$setInputs(init_config = list(version_id = v$version_id, revision = 2L))
    expect_equal(nrow(list_configurations(repo, v$version_id)), 1L)
  })
})

test_that("Shiny rejects selection changes and stale dialog tokens", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  sibling <- register_fixture(repo)
  cfg <- make_config(repo, v$version_id)
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(actor = "tester", version = v$version_id, resource = v$resource_ids[1], config = cfg$config_id)
    session$setInputs(remove = 1)
    token <- state$pending_removal$request_id
    session$setInputs(version = sibling$version_id)
    session$setInputs(confirm_remove = token)
    expect_equal(nrow(list_workspace_inputs(repo)), 2L)
    session$setInputs(version = v$version_id, remove = 2)
    session$setInputs(confirm_remove = token)
    expect_equal(nrow(list_workspace_events(repo, v$version_id)), 0L)
    expect_match(state$notice, "context")
  })
})

test_that("removed view is read only and a remove restore cycle invalidates forms", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  cfg <- make_config(repo, v$version_id)
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(actor = "tester", version = v$version_id, resource = v$resource_ids[1], config = cfg$config_id)
    old_token <- current_context()$token
    set_workspace_state(repo, v$version_id, "removed", 0L, "external-rm", "other")
    session$setInputs(workspace_filter = "removed", refresh = 1)
    expect_match(as.character(output$parser_form$html), "read-only")
    session$setInputs(form_context = old_token, inspect = 1)
    expect_equal(nrow(list_operations(repo)), 0L)
    session$setInputs(restore = list(version_id = v$version_id, revision = 1L))
    expect_equal(get_workspace_state(repo, v$version_id)$state, "active")
    session$setInputs(form_context = old_token, detect = 1)
    expect_equal(nrow(list_configurations(repo, v$version_id)), 1L)
    expect_false(identical(current_context()$token, old_token))
  })
})

test_that("delayed initial, restore and undo clicks never follow a changed selection", {
  repo <- new_test_repo()
  a <- register_fixture(repo)
  b <- register_fixture(repo)
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(actor = "tester", version = a$version_id)
    session$setInputs(version = b$version_id)
    session$setInputs(init_config = 0L)
    expect_equal(nrow(list_configurations(repo, b$version_id)), 0L)
    session$setInputs(init_config = list(version_id = a$version_id, revision = 0L))
    expect_equal(nrow(list_configurations(repo, b$version_id)), 0L)
    set_workspace_state(repo, a$version_id, "removed", 0L, "remove-a", "tester")
    set_workspace_state(repo, b$version_id, "removed", 0L, "remove-b", "tester")
    session$setInputs(workspace_filter = "removed", refresh = 1)
    session$setInputs(restore = list(version_id = a$version_id, revision = 1L))
    expect_equal(get_workspace_state(repo, b$version_id)$state, "removed")
    state$undo <- list(version_id = b$version_id, revision = 1L)
    session$setInputs(undo_remove = list(version_id = a$version_id, revision = 1L))
    expect_equal(get_workspace_state(repo, b$version_id)$state, "removed")
  })
})

test_that("restore preference survives the browser's delayed Active radio update", {
  repo <- new_test_repo()
  a <- register_fixture(repo)
  register_fixture(repo)
  set_workspace_state(repo, a$version_id, "removed", 0L, "rm-pref", "tester")
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(actor = "tester", workspace_filter = "removed", version = a$version_id)
    session$setInputs(restore = list(version_id = a$version_id, revision = 1L))
    expect_equal(state$preferred_version, a$version_id)
    session$setInputs(workspace_filter = "active")
    expect_null(state$preferred_version)
  })
})

test_that("unrelated repository writes do not invalidate the selected form or preview", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  cfg <- make_config(repo, v$version_id)
  other <- register_fixture(repo)
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(actor = "tester", version = v$version_id, resource = v$resource_ids[1], config = cfg$config_id)
    session$setInputs(form_context = current_context()$token, inspect = 1)
    prior <- state$inspection
    set_workspace_state(repo, other$version_id, "removed", 0L, "unrelated-rm", "tester")
    state$source_tick <- state$source_tick + 1L
    session$flushReact()
    expect_equal(state$inspection, prior)
  })
})

test_that("switching to Removed rejects delayed active form actions", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  cfg <- make_config(repo, v$version_id)
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(actor = "tester", version = v$version_id, resource = v$resource_ids[1], config = cfg$config_id)
    token <- current_context()$token
    session$setInputs(workspace_filter = "removed", form_context = token, inspect = 1, detect = 1)
    expect_equal(nrow(list_operations(repo)), 0L)
    expect_equal(nrow(list_configurations(repo, v$version_id)), 1L)
  })
})

test_that("repository refresh projects relevant configuration and operation changes", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  shiny::testServer(workspace_server, args = list(repo = repo), {
    session$setInputs(actor = "tester", version = v$version_id, resource = v$resource_ids[1])
    cfg <- make_config(repo, v$version_id)
    session$setInputs(refresh = 1, config = cfg$config_id)
    expect_equal(lifecycle$configurations()$config_id, cfg$config_id)
    op <- submit_operation(repo, v$version_id, cfg$config_id, "inspect", "external-op", "tester")
    session$setInputs(refresh = 2, operation = op$operation_id)
    expect_match(output$events_table, "queued")
    record_operation_event(repo, op$operation_id, "running", "tester")
    record_operation_event(repo, op$operation_id, "completed", "tester")
    session$setInputs(refresh = 3)
    expect_match(output$events_table, "completed")
  })
})
