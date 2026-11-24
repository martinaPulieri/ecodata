#' Inspect a version through an exact configuration snapshot
#'
#' Produces a bounded lexical preview and schema candidates. It performs no
#' type conversion, scientific validation, relationship reconstruction or source
#' modification. Empty, malformed and unsupported resources retain their bytes
#' and receive explicit limitations. Header aliases never confirm a schema.
#' @param version_id Source version ID.
#' @param config_id Exact configuration snapshot ID.
#' @param repo Open repository handle.
#' @param preview_rows Maximum returned data rows per table (default 20).
#' @param max_preview_bytes Maximum bytes read from a table (default 2 MiB).
#'   Larger inputs are registered but inspection reports a bounded limitation.
#' @return List with version/configuration IDs and per-resource status, diagnostic,
#'   lexical tables, stable source record IDs, candidates and assessment scope.
#' @export
inspect_input <- function(version_id, config_id, repo, preview_rows = 20L, max_preview_bytes = 2 * 1024^2) {
  preview_rows <- integer_bound(preview_rows, "preview_rows", 1000L)
  max_preview_bytes <- integer_bound(max_preview_bytes, "max_preview_bytes", 50 * 1024^2)
  config <- get_configuration(repo, config_id)
  if (config$version_id != version_id) stop("Configuration belongs to a different version")
  verified <- verify_input(repo, version_id)
  if (!verified$ok) stop("Input integrity verification failed")
  output <- vector("list", nrow(verified$resources))
  for (i in seq_len(nrow(verified$resources))) {
    resource <- verified$resources[i, ]
    result <- tryCatch({
      extension <- tolower(tools::file_ext(resource$original_name))
      if (extension %in% c("csv", "tsv")) {
        if (resource$size_bytes > max_preview_bytes) stop("Table exceeds bounded preview byte limit; original retained")
        raw <- readBin(resource$owned_path, "raw", n = max_preview_bytes + 1L)
        table <- parse_preview(raw, config$parsers[[resource$resource_id]], preview_rows, resource$resource_id, "table")
        list(status = "ready", diagnostic = "Lexical preview only; no scientific checks executed", tables = list(table), schema_candidates = character())
      } else if (extension == "zip") {
        inspect_archive(resource$owned_path, resource$resource_id, preview_rows, max_preview_bytes)
      } else list(status = "unsupported", diagnostic = "Unsupported format; original file retained", tables = list(), schema_candidates = character())
    }, error = function(e) list(status = "unreadable", diagnostic = conditionMessage(e), tables = list(), schema_candidates = character()))
    result$resource_id <- resource$resource_id
    result$acquisition_status <- resource$acquisition_status
    result$assessment_scope <- "preview_only"
    # This step has no scientific rule engine, even after a recorded confirmation.
    result$schema_confirmed <- config$schema$confirmed
    result$schema_specific_checks_enabled <- FALSE
    output[[i]] <- result
  }
  # Detect external tampering during inspection before returning interpreted data.
  if (!verify_input(repo, version_id)$ok) stop("Input integrity changed during inspection")
  list(version_id = version_id, config_id = config_id, resources = output)
}

parse_preview <- function(bytes, parser, preview_rows, resource_id, table_key, header = TRUE, record_separator = NULL) {
  parser <- validate_parser(parser)
  if (!length(bytes)) stop("Empty input has no table header")
  # Decode raw vectors directly: UTF-16 legitimately contains zero bytes, which
  # are not valid NUL characters until decoding has established their meaning.
  decoded <- suppressWarnings(iconv(list(bytes), from = parser$encoding, to = "UTF-8", sub = NA, toRaw = TRUE)[[1]])
  if (is.null(decoded)) stop("Input does not match configured encoding")
  if (any(decoded == as.raw(0))) stop("Embedded NUL is not supported")
  text <- rawToChar(decoded)
  if (!validUTF8(text)) stop("Input does not match configured encoding")
  text <- sub("^\ufeff", "", text)
  if (!nzchar(text)) stop("Empty input has no table header")
  # A small strict lexer avoids read.table's quote removal in malformed fields
  # and newline normalisation inside quoted values. All values stay character.
  records <- lexical_records(text, parser, preview_rows + as.integer(header) + 1L, record_separator)
  if (!length(records)) stop("No readable table records")
  width <- length(records[[1]])
  if (any(lengths(records) != width)) stop("Ragged table: inconsistent field counts in preview")
  columns <- if (header) records[[1]] else paste0("column_", seq_len(width))
  rows <- if (header) records[-1] else records
  matrix <- if (length(rows)) matrix(unlist(rows, use.names = FALSE), ncol = width, byrow = TRUE) else matrix(character(), nrow = 0L, ncol = width)
  data <- as.data.frame(matrix, stringsAsFactors = FALSE, optional = TRUE)
  truncated <- nrow(data) > preview_rows
  data <- utils::head(data, preview_rows)
  names(data) <- columns
  rownames(data) <- NULL
  table_id <- paste0(resource_id, ":", table_key)
  list(table_id = table_id, columns = columns, preview = data,
    column_ids = paste0(table_id, ":column:", seq_along(columns)),
    record_ids = if (nrow(data)) paste0(table_id, ":row:", seq_len(nrow(data))) else character(),
    truncated = truncated, parser = parser)
}

# RFC-style field grammar: a quote may open only at a field boundary, a closing
# quote may be followed only by an escaped quote, delimiter, terminator or EOF.
# Field content is sliced from the original decoded text, retaining embedded
# CR, LF and CRLF. Only enclosure and doubled-quote escaping are interpreted.
lexical_records <- function(text, parser, limit, record_separator = NULL) {
  chars <- strsplit(text, "", fixed = TRUE)[[1]]
  n <- length(chars)
  i <- 1L
  start <- 1L
  state <- "start"
  quoted <- FALSE
  fields <- character()
  rows <- list()
  field_value <- function(end) {
    value <- if (end >= start) substr(text, start, end) else ""
    if (quoted) {
      value <- if (nchar(value) > 2L) substr(value, 2L, nchar(value) - 1L) else ""
      value <- gsub(paste0(parser$quote, parser$quote), parser$quote, value, fixed = TRUE)
    }
    value
  }
  while (i <= n) {
    ch <- chars[i]
    if (state == "quoted") {
      if (nzchar(parser$quote) && ch == parser$quote) state <- "after_quote"
      i <- i + 1L
      next
    }
    if (state == "after_quote" && nzchar(parser$quote) && ch == parser$quote) {
      state <- "quoted"
      i <- i + 1L
      next
    }
    delimiter <- ch == parser$delimiter
    newline <- ch %in% c("\r", "\n")
    if (state == "after_quote" && !delimiter && !newline) stop("Invalid character after closing quote")
    if (delimiter || newline) {
      fields <- c(fields, field_value(i - 1L))
      if (newline) {
        actual_separator <- if (ch == "\r" && i < n && chars[i + 1L] == "\n") "\r\n" else ch
        if (!is.null(record_separator) && actual_separator != record_separator) stop("Row terminator does not match declared linesTerminatedBy")
        if (actual_separator == "\r\n") i <- i + 1L
        rows[[length(rows) + 1L]] <- fields
        fields <- character()
        if (length(rows) >= limit) return(rows)
      }
      i <- i + 1L
      start <- i
      state <- "start"
      quoted <- FALSE
      next
    }
    if (nzchar(parser$quote) && ch == parser$quote) {
      if (state != "start") stop("Invalid quote inside unquoted field")
      state <- "quoted"
      quoted <- TRUE
    } else state <- "unquoted"
    i <- i + 1L
  }
  if (state == "quoted") stop("Unclosed quoted field")
  if (start <= n || length(fields)) rows[[length(rows) + 1L]] <- c(fields, field_value(n))
  rows
}
