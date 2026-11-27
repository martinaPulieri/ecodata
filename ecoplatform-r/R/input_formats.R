# A .txt suffix can contain the same delimited bytes as CSV/TSV. Reading still
# requires explicit or detected settings; the suffix does not certify a table.
is_standalone_table <- function(name) {
  tolower(tools::file_ext(name)) %in% c("csv","tsv","txt")
}
