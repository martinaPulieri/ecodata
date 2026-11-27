test_that("two-digit years infer DMY only when the values distinguish month position", {
  expect_equal(infer_date_format(c("17/05/11","12/10/11"))$selected,"dmy-slash-yy")
  expect_equal(infer_date_format("05/17/11")$selected,"mdy-slash-yy")
  expect_null(infer_date_format("12/10/11")$selected)
  expect_equal(unlist(infer_date_format("12/10/11")$candidates),c("dmy-slash-yy","mdy-slash-yy"))
  expect_null(infer_date_format(c("17/05/11","17/05/2011"))$selected)
})

test_that("declared two-digit years preserve their width and never invent a century", {
  repo<-new_test_repo()
  f<-full_fixture(repo,write_fixture("date\n17/05/11\n12/10/11\n17/05/2011\n 17/05/11\n"))
  r<-prepare_date_information(repo,f$v$version_id,f$cfg$config_id)
  cfg<-save_date_declarations(repo,r,list(list(table_id=r$preparation$tables[[1]]$table_id,
    columns=c(value=0),pattern_id="dmy-slash-yy")),"tester")
  out<-run_date_validation(repo,f$v$version_id,cfg$config_id)
  rows<-out$mappings[[1]]$rows
  expect_equal(vapply(rows,`[[`,character(1),"status"),c("recognised","recognised","unrecognised","unrecognised"))
  expect_equal(rows[[1]]$original_values$value,"17/05/11")
  expect_equal(rows[[1]]$candidates[[1]]$pattern$widths$year,2)
  expect_equal(rows[[1]]$observed_widths$value,8)
  expect_false(out$value_conversion)
  expect_equal(cfg$validation_spec$patterns$version,"date-patterns-1.2")
  for(version in c("date-patterns-0.1","date-patterns-1.0","date-patterns-1.1"))
    expect_false("dmy-slash-yy"%in%names(date_patterns(version)$patterns))
  expect_true(verify_input(repo,f$v$version_id)$ok)
})
