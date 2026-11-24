test_that("lexical inspection preserves headers, leading zeros and missing markers", {
  repo <- new_test_repo()
  v <- register_input(write_fixture('id,value,value\n001,0,NA\n002,,"<0.1"\n'), list(), repo)
  cfg <- make_config(repo, v$version_id)
  x <- inspect_input(v$version_id, cfg$config_id, repo)$resources[[1]]
  expect_equal(x$status, "ready")
  expect_identical(x$tables[[1]]$columns, c("id", "value", "value"))
  expect_identical(unname(x$tables[[1]]$preview[[1]]), c("001", "002"))
  expect_identical(unname(x$tables[[1]]$preview[[3]]), c("NA", "<0.1"))
  expect_identical(x$tables[[1]]$preview[[2]], c("0", ""))
  expect_length(unique(x$tables[[1]]$record_ids), 2L)
  expect_false(x$schema_specific_checks_enabled)
})

test_that("explicit delimiter and encoding choices preserve interpretation history", {
  repo <- new_test_repo()
  path <- write_fixture("station;value\n001;1,5\n")
  v <- register_input(path, list(), repo)
  first <- make_config(repo, v$version_id)
  resource <- get_input(repo, v$version_id)$resources$resource_id
  parsers <- setNames(list(list(delimiter = ";", encoding = "UTF-8", decimal_mark = ",", quote = '"')), resource)
  second <- make_config(repo, v$version_id, expected_revision = 1L, parsers = parsers)
  x <- inspect_input(v$version_id, second$config_id, repo)$resources[[1]]
  expect_equal(x$tables[[1]]$columns, c("station", "value"))
  expect_equal(x$tables[[1]]$preview[[2]], "1,5")
  expect_equal(get_configuration(repo, first$config_id)$parsers[[resource]]$delimiter, ",")
  latin <- tempfile(fileext = ".csv")
  writeBin(as.raw(c(110,97,109,101,10,99,97,102,233,10)), latin)
  lv <- register_input(latin, list(), repo)
  rid <- get_input(repo, lv$version_id)$resources$resource_id
  lp <- setNames(list(list(delimiter = ",", encoding = "latin1", decimal_mark = ".", quote = '"')), rid)
  lc <- make_config(repo, lv$version_id, parsers = lp)
  expect_equal(inspect_input(lv$version_id, lc$config_id, repo)$resources[[1]]$tables[[1]]$preview[[1]], "caf\u00e9")
})

test_that("empty and malformed inputs are inspectable limitations rather than successes", {
  repo <- new_test_repo()
  for (text in c("", "a,b\n1,2,3\n", 'a,b\n1,"unclosed\n')) {
    v <- register_input(write_fixture(text), list(), repo)
    cfg <- make_config(repo, v$version_id)
    x <- inspect_input(v$version_id, cfg$config_id, repo)$resources[[1]]
    expect_equal(x$status, "unreadable")
    expect_true(nzchar(x$diagnostic))
    expect_true(verify_input(repo, v$version_id)$ok)
  }
})

test_that("preview is bounded and explicitly does not validate the whole population", {
  repo <- new_test_repo()
  v <- register_fixture(repo)
  cfg <- make_config(repo, v$version_id)
  x <- inspect_input(v$version_id, cfg$config_id, repo, preview_rows = 1L)$resources[[1]]
  expect_equal(nrow(x$tables[[1]]$preview), 1L)
  expect_true(x$tables[[1]]$truncated)
  expect_equal(x$assessment_scope, "preview_only")
})

test_that("archive safety rejects traversal, absolute paths and expansion limits before extraction", {
  expect_error(check_archive_entries(data.frame(Name = "../escape.csv", Length = 1)), "unsafe")
  expect_error(check_archive_entries(data.frame(Name = "C:/escape.csv", Length = 1)), "unsafe")
  expect_error(check_archive_entries(data.frame(Name = "\\\\server\\x", Length = 1)), "unsafe")
  expect_error(check_archive_entries(data.frame(Name = c("A.csv", "a.csv"), Length = c(1, 1))), "duplicate")
  expect_error(check_archive_entries(data.frame(Name = "large.csv", Length = 101), max_expanded_bytes = 100), "expanded")
  expect_error(check_archive_entries(data.frame(Name = c("a", "b"), Length = c(1, 1)), max_entries = 1L), "entries")
})

test_that("safe DwC-A inspection identifies declarations without confirming schema", {
  repo <- new_test_repo()
  source_dir <- tempfile("dwca-")
  dir.create(source_dir)
  writeLines('<archive xmlns="http://rs.tdwg.org/dwc/text/"><core rowType="http://rs.tdwg.org/dwc/terms/Occurrence" fieldsTerminatedBy="," ignoreHeaderLines="1"><files><location>occurrence.csv</location></files><id index="0"/><field index="0" term="http://rs.tdwg.org/dwc/terms/occurrenceID"/></core></archive>', file.path(source_dir, "meta.xml"))
  writeLines("occurrenceID\n001", file.path(source_dir, "occurrence.csv"))
  archive <- tempfile(fileext = ".zip")
  zip::zipr(archive, c("meta.xml", "occurrence.csv"), root = source_dir)
  v <- register_input(archive, list(), repo)
  cfg <- make_config(repo, v$version_id)
  x <- inspect_input(v$version_id, cfg$config_id, repo)$resources[[1]]
  expect_equal(x$status, "ready")
  expect_equal(x$schema_candidates, "dwc_occurrence")
  expect_false(x$schema_specific_checks_enabled)
  expect_equal(x$tables[[1]]$member, "occurrence.csv")
  expect_equal(x$tables[[1]]$declared_columns, "http://rs.tdwg.org/dwc/terms/occurrenceID")
  expect_true(verify_input(repo, v$version_id)$ok)
})

test_that("illegal quote placement never silently changes lexical CSV values", {
  repo <- new_test_repo()
  for (text in c('a,b\n1,x"y"\n', 'a,b\n1,"b"c\n')) {
    v <- register_input(write_fixture(text), list(), repo)
    cfg <- make_config(repo, v$version_id)
    x <- inspect_input(v$version_id, cfg$config_id, repo)$resources[[1]]
    expect_equal(x$status, "unreadable")
    expect_match(x$diagnostic, "quote")
    expect_true(verify_input(repo, v$version_id)$ok)
  }
  v <- register_input(write_fixture('a,b\n1,"a""b"\n'), list(), repo)
  cfg <- make_config(repo, v$version_id)
  expect_identical(inspect_input(v$version_id, cfg$config_id, repo)$resources[[1]]$tables[[1]]$preview[[2]], 'a"b')
  crlf <- register_input(write_fixture('a,b\r\n1,"line1\r\nline2"\r\n'), list(), repo)
  ccfg <- make_config(repo, crlf$version_id)
  expect_identical(inspect_input(crlf$version_id, ccfg$config_id, repo)$resources[[1]]$tables[[1]]$preview[[2]], "line1\r\nline2")
})

test_that("header-only tables have no invented records or row identifiers", {
  repo <- new_test_repo()
  v <- register_input(write_fixture("a,b\n"), list(), repo)
  cfg <- make_config(repo, v$version_id)
  table <- inspect_input(v$version_id, cfg$config_id, repo)$resources[[1]]$tables[[1]]
  expect_equal(nrow(table$preview), 0L)
  expect_identical(table$record_ids, character())
  expect_identical(table$columns, c("a", "b"))
})

test_that("archive descriptors reject repeated members and unsupported row syntax", {
  repo <- new_test_repo()
  for (attrs in c('linesTerminatedBy="|"', 'ignoreHeaderLines="1.5"', 'duplicate="yes"')) {
    source_dir <- tempfile("bad-dwca-")
    dir.create(source_dir)
    locations <- if (grepl("duplicate", attrs)) "<location>a.csv</location><location>a.csv</location>" else "<location>a.csv</location>"
    descriptor <- paste0('<archive><core rowType="http://rs.tdwg.org/dwc/terms/Occurrence" ', attrs, '><files>', locations, '</files></core></archive>')
    writeLines(descriptor, file.path(source_dir, "meta.xml"))
    writeLines("id\n001", file.path(source_dir, "a.csv"))
    archive <- tempfile(fileext = ".zip")
    zip::zipr(archive, c("meta.xml", "a.csv"), root = source_dir)
    v <- register_input(archive, list(), repo)
    cfg <- make_config(repo, v$version_id)
    x <- inspect_input(v$version_id, cfg$config_id, repo)$resources[[1]]
    expect_equal(x$status, "unreadable")
    expect_true(nzchar(x$diagnostic))
  }
})

test_that("TSV defaults accept a tab delimiter without changing lexical values", {
  repo <- new_test_repo()
  v <- register_input(write_fixture("id\tvalue\n001\tNA\n", ".tsv"), list(), repo)
  cfg <- make_config(repo, v$version_id)
  x <- inspect_input(v$version_id, cfg$config_id, repo)$resources[[1]]
  expect_equal(x$status, "ready")
  expect_identical(x$tables[[1]]$preview[[1]], "001")
  expect_identical(x$tables[[1]]$preview[[2]], "NA")
})

test_that("explicit UTF-16 decoding supports Excel-style files and retains bytes", {
  repo <- new_test_repo()
  path <- tempfile(fileext = ".csv")
  original <- as.raw(c(255,254,105,0,100,0,44,0,118,0,10,0,48,0,48,0,49,0,44,0,233,0,10,0))
  writeBin(original, path)
  v <- register_input(path, list(), repo)
  rid <- get_input(repo, v$version_id)$resources$resource_id
  parsers <- setNames(list(list(delimiter = ",", encoding = "UTF-16LE", decimal_mark = ".", quote = '"')), rid)
  cfg <- make_config(repo, v$version_id, parsers = parsers)
  x <- inspect_input(v$version_id, cfg$config_id, repo)$resources[[1]]
  expect_equal(x$status, "ready")
  expect_identical(x$tables[[1]]$preview[[1]], "001")
  expect_identical(x$tables[[1]]$preview[[2]], "\u00e9")
  expect_identical(readBin(path, "raw", n = 100), original)
  expect_true(verify_input(repo, v$version_id)$ok)
})
