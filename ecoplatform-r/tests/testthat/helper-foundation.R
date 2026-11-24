new_test_repo <- function() {
  root <- tempfile("ecodata-test-")
  repo <- open_repository(root)
  withr::defer(close_repository(repo), envir = parent.frame())
  repo
}

write_fixture <- function(text = "id,value\n001,0\n002,NA\n", suffix = ".csv") {
  path <- tempfile(fileext = suffix)
  writeBin(charToRaw(text), path)
  path
}

register_fixture <- function(repo, ...) register_input(write_fixture(), list(title = "Synthetic"), repo, ...)

make_config <- function(repo, version_id, ...) {
  save_configuration(repo, version_id, actor_id = "tester", ...)
}
