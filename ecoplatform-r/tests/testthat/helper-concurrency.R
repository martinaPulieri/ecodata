# Independent processes exercise SQLite writer reservations, not mocked locks.
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
