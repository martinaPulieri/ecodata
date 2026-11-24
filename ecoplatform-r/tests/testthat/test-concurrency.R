# Independent R processes expose real SQLite/file races rather than mocked locks.
concurrent_workers <- function(fn, args, open_root = NULL) {
  cluster <- parallel::makePSOCKcluster(2L)
  withr::defer(parallel::stopCluster(cluster))
  libraries <- .libPaths()
  package_path <- getNamespaceInfo(asNamespace("ecodata"), "path")
  parallel::clusterCall(cluster, function(libs, path) {
    .libPaths(libs)
    if (file.exists(file.path(path, "R", "repository_connection.R"))) pkgload::load_all(path, quiet = TRUE)
    else library(ecodata)
    NULL
  }, libraries, package_path)
  if (!is.null(open_root)) parallel::clusterCall(cluster, function(root) {
    assign("migration_repo", open_repository(root), envir = .GlobalEnv)
    NULL
  }, open_root)
  parallel::parLapply(cluster, args, fn)
}

test_that("concurrent first opens initialise exactly one valid schema", {
  root <- tempfile("concurrent-open-")
  results <- concurrent_workers(function(root) {
    tryCatch({
      repo <- open_repository(root)
      on.exit(close_repository(repo))
      DBI::dbGetQuery(repo$con, "PRAGMA user_version")[[1]]
    }, error = conditionMessage)
  }, list(root, root))
  expect_equal(results, list(1L, 1L))
})

test_that("concurrent migrations recheck version under the writer reservation", {
  repo <- new_test_repo()
  root <- repo$root
  results <- concurrent_workers(function(root) {
    tryCatch({
      repo <- get("migration_repo", envir = .GlobalEnv)
      on.exit(close_repository(repo))
      migrate_repository(repo$con, statements = "CREATE TABLE migration_once (id INTEGER)", target_version = 2L)
    }, error = conditionMessage)
  }, list(root, root), open_root = root)
  expect_equal(results, list(2L, 2L))
  expect_equal(DBI::dbGetQuery(repo$con, "PRAGMA user_version")[[1]], 2L)
  expect_true(DBI::dbExistsTable(repo$con, "migration_once"))
})

test_that("concurrent snapshots publish one destination without overwriting it", {
  repo <- new_test_repo()
  register_fixture(repo)
  destination <- file.path(repo$root, "backups", "exclusive.sqlite")
  results <- concurrent_workers(function(args) {
    tryCatch({
      repo <- open_repository(args$root)
      on.exit(close_repository(repo))
      backup_repository(repo, args$destination)
      "published"
    }, error = conditionMessage)
  }, rep(list(list(root = repo$root, destination = destination)), 2L))
  expect_equal(sum(vapply(results, identical, logical(1), "published")), 1L)
  con <- DBI::dbConnect(RSQLite::SQLite(), destination)
  withr::defer(DBI::dbDisconnect(con))
  expect_equal(DBI::dbGetQuery(con, "PRAGMA integrity_check")[[1]], "ok")
  expect_equal(DBI::dbGetQuery(con, "SELECT count(*) AS n FROM dataset_versions")$n, 1L)
})

test_that("a failed snapshot never publishes a partial destination", {
  repo <- new_test_repo()
  close_repository(repo)
  destination <- tempfile(fileext = ".sqlite")
  expect_error(backup_repository(repo, destination))
  expect_false(file.exists(destination))
})
