test_that("portable context and result identities are checked independently of hashes", {
  repo <- new_test_repo(); f <- contract_mapping(repo)
  cfg <- make_config(repo, f$version$version_id, validation_spec = new_validation_spec(list(f$mapping)))
  ctx <- freeze_validation_context(repo, cfg$config_id)
  values <- c(day = "01", month = "03", year = "2020")
  portable <- ctx; portable$version_id <- NULL; portable$config_id <- NULL
  portable$config_hash <- "fake"; portable$resources[[1]]$sha256 <- NULL
  portable$context_hash <- NULL; portable$context_hash <- hash_text(json_text(portable))
  expect_error(new_date_result(portable, "sampling", 1, values, "recognised", "split-numeric"), "context")
  row <- new_date_result(ctx, "sampling", 1, values, "recognised", "split-numeric")
  row$version_id <- "foreign"; row$config_id <- "foreign"; row$table_id <- "foreign"
  row$record_hash <- NULL; row$record_hash <- hash_text(json_text(row))
  expect_error(summarise_date_results(ctx, "sampling", list(row), 1), "identity")
  expect_error(new_date_result(ctx, "sampling", 9007199254740991, values, "recognised", "split-numeric"), "row")
})

test_that("named positional inputs stay aligned through JSON serialisation", {
  table <- new_validation_table("v", "r", c(z = "first", a = "second"))
  expect_equal(unlist(table$headers, use.names = FALSE), c("first", "second"))
  mapping <- new_date_mapping(table, "date", "sampling_date", c(value = 0), "user", "tester", "Explicit", TRUE)
  expect_equal(mapping$columns$value$original_header, "first")
  spec <- new_validation_spec(list(mapping), enabled_rules = c(z = "TMP-00", a = "TMP-02"))
  expect_null(names(spec$enabled_rules))
  repo <- new_test_repo(); v <- register_input(write_fixture("archive", ".zip"), list(), repo)
  core <- new_validation_table(v$version_id, v$resource_ids[1], "id", "core.txt")
  ext <- new_validation_table(v$version_id, v$resource_ids[1], "coreid", "ext.txt")
  link <- new_linkage_mapping(core, 0, ext, 0, "relation", "tester", "Declared", TRUE)
  cfg <- make_config(repo, v$version_id, validation_spec = new_validation_spec(linkage_mappings = list(link)))
  ctx <- freeze_validation_context(repo, cfg$config_id)
  aligned <- new_validation_finding(ctx, "LNK-07", core$table_id, c(second = 1, first = 2), c("first value", "second value"), "Coverage")
  expect_equal(unlist(aligned$row_numbers, use.names = FALSE), c(1, 2))
  expect_equal(unlist(aligned$original_values, use.names = FALSE), c("first value", "second value"))
  expect_null(names(aligned$row_numbers))
  expect_error(new_validation_finding(ctx, "LNK-08", core$table_id, 1, "001", "No whitespace"), "whitespace")
})

test_that("inheritance refuses a corrupted prior configuration", {
  repo <- new_test_repo(); f <- contract_mapping(repo)
  first <- make_config(repo, f$version$version_id, validation_spec = new_validation_spec(list(f$mapping)))
  # Deliberate corruption in an isolated temporary test database only.
  DBI::dbExecute(repo$con, "DROP TRIGGER configuration_revisions_update_immutable")
  row <- DBI::dbGetQuery(repo$con, "SELECT payload_json FROM configuration_revisions WHERE config_id = ?", params = list(first$config_id))
  payload <- decode_json(row$payload_json)
  payload$validation_spec$date_mappings[[1]]$evidence <- "Corrupted evidence"
  DBI::dbExecute(repo$con, "UPDATE configuration_revisions SET payload_json = ? WHERE config_id = ?", params = list(json_text(payload), first$config_id))
  expect_error(make_config(repo, f$version$version_id, expected_revision = 1L), "integrity")
  expect_equal(nrow(list_configurations(repo, f$version$version_id)), 1L)
})

test_that("published catalogue versions keep their canonical content digests", {
  spec <- new_validation_spec()
  expect_equal(spec$rules$sha256, "44457d3363dfbe2c2233d499cdcbf0a9cac309ecae2163b3148d389fb4aa004e")
  expect_equal(spec$patterns$sha256, "f856a3081771ede6e57dcd3855beb89e67abd532d16d3a8d06ee5acefe20484f")
})
