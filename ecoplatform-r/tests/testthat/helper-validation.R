contract_mapping <- function(repo, version = NULL) {
  if (is.null(version)) version <- register_input(write_fixture("anno,giorno,mese,data_analisi\n2020,7,03,03/04/2020\n"), list(title = "Synthetic date contract"), repo)
  table <- new_validation_table(version$version_id, version$resource_ids[1], c("anno", "giorno", "mese", "data_analisi"))
  mapping <- new_date_mapping(table, "sampling", "sampling_date", c(year = 0L, day = 1L, month = 2L),
    "user", "tester", "Confirmed component assignments", confirmed = TRUE)
  list(version = version, table = table, mapping = mapping)
}
