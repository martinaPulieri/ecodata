test_that("BOM encodings and quote-aware separators are detected from bytes", {
  repo <- new_test_repo()
  cases <- list(
    list(text = 'id;note\n001;"a,b"\n002;"c,d"\n', encoding = "UTF-8", delimiter = ";"),
    list(text = "id\tvalue\n001\tNA\n002\t0\n", encoding = "UTF-16LE", delimiter = "\t"),
    list(text = "id|value\n001|0\n002|NA\n", encoding = "UTF-16BE", delimiter = "|"))
  for (case in cases) {
    bytes <- iconv(case$text, from = "UTF-8", to = case$encoding, toRaw = TRUE)[[1]]
    bom <- switch(case$encoding, "UTF-8" = as.raw(c(239,187,191)), "UTF-16LE" = as.raw(c(255,254)), "UTF-16BE" = as.raw(c(254,255)))
    path <- tempfile(fileext = ".csv")
    writeBin(c(bom, bytes), path)
    detected <- detect_parser(path)
    expect_equal(detected$status, "detected")
    expect_equal(detected$parser$encoding, case$encoding)
    expect_equal(detected$parser$delimiter, case$delimiter)
    expect_equal(detected$encoding$method, "bom")
  }
})

test_that("UTF-8 compatibility and CSV quoting determine separators without rewriting values", {
  path <- write_fixture('id,value,note\n001,"1,5","a;b"\n002,0,"c;d"\n')
  x <- detect_parser(path)
  expect_equal(x$status, "detected")
  expect_equal(x$parser$delimiter, ",")
  expect_equal(x$encoding$method, "valid_utf8")
  expect_identical(readBin(path, "raw", n = 100), charToRaw('id,value,note\n001,"1,5","a;b"\n002,0,"c;d"\n'))
})

test_that("ambiguous, binary, unsupported and underspecified inputs are not called detected", {
  for (text in c("a,b;c\n1,2;3\n", "value\n001\n", "a,b\n", "a,b\n1,2,3\n", "")) {
    x <- detect_parser(write_fixture(text))
    expect_false(x$status == "detected")
    expect_true(nzchar(x$message))
  }
  path <- tempfile(fileext = ".csv")
  writeBin(as.raw(c(110,97,109,101,10,99,97,102,233,10)), path)
  expect_equal(detect_parser(path)$encoding$status, "unresolved")
  writeBin(as.raw(c(97,0,98,0,10,0)), path)
  expect_equal(detect_parser(path)$encoding$status, "unresolved")
  writeBin(as.raw(c(255,254,0,0,97,0,0,0)), path)
  expect_equal(detect_parser(path)$encoding$status, "unsupported")
  expect_equal(detect_parser(write_fixture("not tabular", ".zip"))$status, "archive_declared")
})

test_that("invalid UTF-8 remains a quiet actionable preview limitation", {
  repo <- new_test_repo()
  path <- tempfile(fileext = ".csv")
  writeBin(as.raw(c(110,97,109,101,10,99,97,102,233,10)), path)
  v <- register_input(path, list(), repo)
  cfg <- make_config(repo, v$version_id)
  expect_no_warning(x <- inspect_input(v$version_id, cfg$config_id, repo)$resources[[1]])
  expect_equal(x$status, "unreadable")
  expect_match(x$diagnostic, "configured encoding")
})

test_that("bounded detection records its sample and does not require a whole file", {
  path <- write_fixture(paste0("id,value\n", paste(rep("001,0\n", 10000), collapse = "")))
  x <- detect_parser(path, max_sample_bytes = 1024L)
  expect_equal(x$status, "detected")
  expect_equal(x$sample_bytes, 1024L)
  expect_true(x$sample_truncated)
})

test_that("sampling never hides invalid bytes as incomplete Unicode tails", {
  path <- tempfile(fileext = ".csv")
  prefix <- charToRaw("a,b\n1,2\n")
  writeBin(c(prefix, as.raw(255), charToRaw("\n3,4\n")), path)
  expect_equal(detect_parser(path, max_sample_bytes = 9L)$encoding$status, "unresolved")
  # A genuine unfinished UTF-8 sequence may be trimmed at a truncated boundary.
  writeBin(c(prefix, as.raw(c(195,169)), charToRaw(",3\n")), path)
  good <- detect_parser(path, max_sample_bytes = 9L)
  expect_equal(good$encoding$status, "detected")
  expect_equal(good$encoding$trimmed_tail_bytes, 1L)
  wide <- c(as.raw(c(255,254)), iconv("a,b\n1,2\n", from = "UTF-8", to = "UTF-16LE", toRaw = TRUE)[[1]])
  writeBin(c(wide, as.raw(c(0,220,10,0))), path) # isolated low surrogate is invalid
  expect_equal(detect_parser(path, max_sample_bytes = length(wide) + 2L)$encoding$status, "identified_but_invalid")
  writeBin(c(wide, as.raw(c(0,216,0,220,10,0))), path) # high surrogate awaiting its pair
  good_wide <- detect_parser(path, max_sample_bytes = length(wide) + 2L)
  expect_equal(good_wide$encoding$status, "detected")
  expect_equal(good_wide$encoding$trimmed_tail_bytes, 2L)
})

test_that("a truncated last record cannot manufacture separator certainty", {
  path <- write_fixture("a,b;c\n1,2;3\n4,5;6\n")
  sampled <- detect_parser(path, max_sample_bytes = 15L)
  expect_equal(sampled$delimiter$status, "ambiguous")
  expect_false(sampled$status == "detected")
  expect_equal(detect_parser(path)$delimiter$status, "ambiguous")
})

test_that("upload uses detection and manual overrides retain evidence and old snapshots", {
  repo <- new_test_repo()
  path <- write_fixture("id;value\n001;0\n002;NA\n")
  uploaded <- data.frame(name = "auto.csv", size = file.info(path)$size, type = "", datapath = path)
  v <- register_uploaded_inputs(repo, uploaded, "Autodetection", "tester")
  cfg <- get_configuration(repo, v$config_id)
  rid <- get_input(repo, v$version_id)$resources$resource_id
  expect_equal(cfg$parsers[[rid]]$delimiter, ";")
  expect_equal(cfg$parser_detection[[rid]]$status, "detected")
  expect_equal(cfg$parser_detection[[rid]]$resource_sha256, get_input(repo, v$version_id)$resources$sha256)
  parsers <- cfg$parsers
  parsers[[rid]]$delimiter <- "|"
  edited <- save_configuration(repo, v$version_id, parsers = parsers, parser_detection = cfg$parser_detection,
    expected_revision = 1L, actor_id = "tester")
  expect_equal(get_configuration(repo, v$config_id)$parsers[[rid]]$delimiter, ";")
  expect_equal(edited$parser_detection[[rid]]$parser$delimiter, ";")
  expect_equal(edited$parsers[[rid]]$delimiter, "|")
})

test_that("explicit redetection creates a new revision and rejects stale contexts", {
  repo <- new_test_repo()
  v <- register_input(write_fixture("id;value\n001;0\n"), list(), repo)
  first <- make_config(repo, v$version_id)
  rid <- get_input(repo, v$version_id)$resources$resource_id
  next_cfg <- redetect_configuration(repo, first$config_id, rid, "tester")
  expect_equal(next_cfg$revision, 2L)
  expect_equal(next_cfg$parsers[[rid]]$delimiter, ";")
  expect_equal(get_configuration(repo, first$config_id)$parsers[[rid]]$delimiter, ",")
  expect_error(redetect_configuration(repo, first$config_id, rid, "tester"), "stale")
  expect_equal(nrow(list_configurations(repo, v$version_id)), 2L)
})
