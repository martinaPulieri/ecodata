scope_fixture <- function(repo,core,extension) {
  f<-full_fixture(repo,plain_zip_fixture(list(
    "Occurrence.tsv"=paste0("dataset_id\tid\n",core),
    "MeasurementOrFact.tsv"=paste0("dataset_id\tid\n",extension))))
  read_validation_tables(repo,f$v$version_id,f$cfg$config_id)
}
scope_check <- function(input)compare_linkage_key_scope(input,input$tables[[1]]$table_id,
  input$tables[[2]]$table_id,1,1,0,0)

test_that("scope audit distinguishes observed single-column sufficiency from compound necessity", {
  repo<-new_test_repo()
  x<-scope_fixture(repo,"A\t001\nB\t002\n","A\t001\nB\t002\n")
  d<-scope_check(x)
  expect_equal(d$resolution,"single_key_sufficient_for_this_snapshot")
  expect_true(d$settings_provisional)
  expect_false(d$mapping_adopted)
  expect_equal(d$single_key$matching$linked,2L)
  expect_equal(d$compound_key$matching$linked,2L)
  expect_equal(d$namespace_disagreements,0L)
  expect_equal(nrow(list_configurations(repo,x$version_id)),1L)
  x<-scope_fixture(repo,"A\t001\nB\t001\n","A\t001\nB\t001\n")
  d<-scope_check(x)
  expect_equal(d$resolution,"compound_key_required_for_uniqueness")
  expect_equal(d$cross_namespace_id_groups,1L)
  expect_equal(d$single_key$matching$ambiguous,2L)
  expect_equal(d$compound_key$matching$linked,2L)
  expect_false(d$mapping_adopted)
})

test_that("scope audit discloses conflicts missing components and insufficient compound keys", {
  repo<-new_test_repo()
  d<-scope_check(scope_fixture(repo,"A\t001\n","B\t001\n"))
  expect_equal(d$resolution,"namespace_conflict")
  expect_equal(d$namespace_disagreements,1L)
  expect_equal(d$compound_key$matching$unresolved_reference,1L)
  d<-scope_check(scope_fixture(repo,"A\t001\n","\t001\n"))
  expect_equal(d$resolution,"insufficient_information")
  expect_equal(d$missing_extension_scope,1L)
  d<-scope_check(scope_fixture(repo,"A\t001\nA\t001\n","A\t001\n"))
  expect_equal(d$resolution,"compound_key_insufficient")
  expect_equal(d$compound_key$core_duplicate_groups,1L)
})

test_that("tuple encoding cannot collide on source delimiters and preserves literal NA and zeros", {
  repo<-new_test_repo()
  d<-scope_check(scope_fixture(repo,"a:b\tc\na\tb:c\nNA\t001\n","a:b\tc\na\tb:c\nNA\t001\n"))
  expect_equal(d$compound_key$core_duplicate_groups,0L)
  expect_equal(d$compound_key$matching$linked,3L)
  expect_equal(d$single_key$core_missing_rows,0L)
  expect_error(compare_linkage_key_scope(scope_fixture(repo,"A\t001\n","A\t001\n"),"foreign","other",1,1,0,0),"table")
})
