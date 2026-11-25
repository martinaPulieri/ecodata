#' Check an archive directory before opening any member
#'
#' Members are read through unz() streams, never extracted into the filesystem.
#' Reject path traversal, Windows aliases, absolute names, duplicate names and
#' declared size/count excesses. Actual member bytes are separately bounded.
#' @param entries Data frame with Name and Length from utils::unzip(list=TRUE).
#' @param max_expanded_bytes Maximum declared total uncompressed bytes (200 MiB).
#' @param max_entries Maximum archive member count (1000).
#' @return Original directory data frame, invisibly, if safe.
#' @export
check_archive_entries <- function(entries, max_expanded_bytes = 200 * 1024^2, max_entries = 1000L) {
  integer_bound(max_entries, "max_entries", 100000L)
  if (!is.numeric(max_expanded_bytes) || length(max_expanded_bytes) != 1L || !is.finite(max_expanded_bytes) || max_expanded_bytes < 1) stop("Invalid expanded byte limit")
  if (!is.data.frame(entries) || !all(c("Name", "Length") %in% names(entries)) || !nrow(entries)) stop("Empty or invalid archive directory")
  if (nrow(entries) > max_entries) stop("Archive entries limit exceeded")
  names <- gsub("\\", "/", entries$Name, fixed = TRUE)
  if (anyNA(names) || any(!nzchar(names)) || any(grepl("^/|:|(^|/)\\.{1,2}(/|$)|[. ](/|$)|//", names)) || any(grepl("(^|/)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])([./]|$)", names, ignore.case = TRUE))) stop("Archive contains unsafe member paths")
  if (anyDuplicated(tolower(sub("/$", "", names)))) stop("Archive contains duplicate member names")
  if (!is.numeric(entries$Length) || anyNA(entries$Length) || any(!is.finite(entries$Length)) || any(entries$Length < 0) || sum(entries$Length) > max_expanded_bytes) stop("Archive expanded byte limit exceeded")
  invisible(entries)
}

read_member <- function(path, member, max_bytes) {
  con <- unz(path, member, open = "rb")
  on.exit(close(con))
  bytes <- readBin(con, "raw", n = max_bytes + 1)
  if (length(bytes) > max_bytes) stop("Archive member exceeds bounded read size")
  bytes
}

inspect_archive <- function(path, resource_id, preview_rows, max_preview_bytes, configuration=NULL) {
  entries <- utils::unzip(path, list = TRUE)
  check_archive_entries(entries)
  metas <- entries$Name[grepl("(^|/)meta\\.xml$", entries$Name,ignore.case=TRUE)]
  if(!length(metas))return(inspect_plain_archive(path,resource_id,preview_rows,max_preview_bytes,configuration))
  if (length(metas) != 1L) return(list(status = "unsupported", diagnostic = "ZIP has no single supported DwC-A meta.xml descriptor", tables = list(), schema_candidates = character()))
  bytes <- read_member(path, metas, min(max_preview_bytes, 1024^2))
  if (grepl("<!DOCTYPE|<!ENTITY", rawToChar(bytes), ignore.case = TRUE)) stop("DTD/entity declarations are not supported")
  doc <- xml2::read_xml(bytes, options = "NONET")
  root <- xml2::xml_find_first(doc, "/*[local-name()='archive']")
  if (inherits(root, "xml_missing")) stop("Invalid DwC-A archive descriptor")
  nodes <- xml2::xml_find_all(root, "./*[local-name()='core' or local-name()='extension']")
  if (!length(nodes)) stop("Descriptor has no core or extension tables")
  tables <- list()
  candidates <- character()
  # Validate the complete reference set before decompressing any table. A ZIP
  # member may not be read repeatedly through duplicated descriptor locations.
  referenced <- character()
  for (node in nodes) {
    locations <- xml2::xml_text(xml2::xml_find_all(node, "./*[local-name()='files']/*[local-name()='location']"))
    for (location in locations) {
      check_archive_entries(data.frame(Name = location, Length = 0))
      member <- if (dirname(metas) == ".") location else paste(dirname(metas), location, sep = "/")
      if (!member %in% entries$Name) stop("Declared archive member is missing")
      referenced <- c(referenced, member)
    }
  }
  if (anyDuplicated(tolower(referenced))) stop("Descriptor has duplicate member references")
  attr_or <- function(node, key, default) {
    value <- xml2::xml_attr(node, key)
    if (is.na(value)) default else value
  }
  for (node in nodes) {
    locations <- xml2::xml_text(xml2::xml_find_all(node, "./*[local-name()='files']/*[local-name()='location']"))
    if (!length(locations)) stop("Descriptor table has no file location")
    row_type <- attr_or(node, "rowType", "")
    profile <- if (grepl("/Occurrence$", row_type)) "dwc_occurrence" else if (grepl("/Event$", row_type)) "dwc_event" else if (grepl("/(ExtendedMeasurementOrFact|MeasurementOrFact)$", row_type)) "dwc_measurement" else character()
    candidates <- unique(c(candidates, profile))
    delimiter <- attr_or(node, "fieldsTerminatedBy", ",")
    if (identical(delimiter, "\\t")) delimiter <- "\t"
    quote <- attr_or(node, "fieldsEnclosedBy", '"')
    ignore_text <- attr_or(node, "ignoreHeaderLines", "0")
    if (!ignore_text %in% c("0", "1")) stop("Only integer zero or one declared header line is supported")
    ignore <- as.integer(ignore_text)
    line_attr <- xml2::xml_attr(node, "linesTerminatedBy")
    line_separator <- if (is.na(line_attr)) NULL else switch(line_attr, "\\n" = "\n", "\\r\\n" = "\r\n", "\\r" = "\r", line_attr)
    if (!is.null(line_separator) && !line_separator %in% c("\n", "\r\n", "\r")) stop("Unsupported linesTerminatedBy")
    parser <- validate_parser(list(delimiter = delimiter, encoding = attr_or(node, "encoding", "UTF-8"), decimal_mark = ".", quote = quote))
    declared_columns <- xml2::xml_attr(xml2::xml_find_all(node, "./*[local-name()='field']"), "term")
    for (location in locations) {
      check_archive_entries(data.frame(Name = location, Length = 0))
      prefix <- dirname(metas)
      member <- if (prefix == ".") location else paste(prefix, location, sep = "/")
      if (!member %in% entries$Name) stop("Declared archive member is missing")
      # Bounded member reads avoid trusting ZIP directory lengths alone.
      raw <- read_member(path, member, max_preview_bytes)
      table <- parse_preview(raw, parser, preview_rows, resource_id, member, header = ignore == 1L, record_separator = line_separator)
      table$member <- member
      table$row_type <- row_type
      table$declared_columns <- declared_columns
      table$declared_parser <- parser
      table$declared_parser$lines_terminated_by <- if (is.null(line_separator)) "unspecified; native CR/LF/CRLF" else line_separator
      tables[[length(tables) + 1L]] <- table
    }
  }
  list(status = "ready", diagnostic = "DwC-A declaration inspected; schema confirmation and scientific checks are separate", tables = tables, schema_candidates = candidates)
}
