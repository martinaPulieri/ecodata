#' Detect a tabular file's encoding and separator from a bounded sample
#'
#' BOMs establish UTF-8/UTF-16 byte order; otherwise only NUL-free valid UTF-8
#' is automatically accepted. Legacy encodings without a BOM are ambiguous.
#' A separator is selected only when exactly one comma/semicolon/tab/pipe
#' candidate has consistent multi-column records in the quote-aware sample.
#' Unresolved components retain defaults in this result; callers must check each
#' component's status before applying it over an existing manual configuration.
#' No scientific fields, date conventions or decimal meanings are inferred.
#' @param path Existing local file to sample; never modified.
#' @param original_name Original filename, independent of upload temporary path.
#' @param max_sample_bytes Maximum read budget, default 1 MiB, at most 2 MiB.
#' @param quote Existing quote convention, double quote or empty string.
#' @return List containing parser settings, component status/evidence, detector
#'   version, sample hash/size and a human-readable limitation or summary.
#' @export
detect_parser <- function(path, original_name = basename(path), max_sample_bytes = 1024^2, quote = '"') {
  scalar_text(path, "path")
  scalar_text(original_name, "original_name")
  max_sample_bytes <- integer_bound(max_sample_bytes, "max_sample_bytes", 2 * 1024^2)
  parser <- default_parser(original_name)
  parser$quote <- quote
  validate_parser(parser)
  result <- list(detector_version = "parser-detection-1.0", status = "needs_review", parser = parser,
    encoding = list(status = "unresolved", method = "none"),
    delimiter = list(status = "unresolved", candidates = list()),
    sample_bytes = 0L, sample_truncated = FALSE,
    message = "Insufficient evidence; verify encoding and separator manually.")
  extension <- tolower(tools::file_ext(original_name))
  if (extension == "zip") {
    result$status <- "archive_declared"
    result$message <- "Archive table settings come from its immutable descriptor."
    return(result)
  }
  if (!is_standalone_table(original_name)) {
    result$status <- "unsupported"
    result$message <- "Automatic detection is available for CSV/TSV/delimited TXT files."
    return(result)
  }
  info <- file.info(path)
  if (is.na(info$size) || info$isdir) stop("Detection requires an existing regular file")
  con <- file(path, "rb")
  bytes <- tryCatch(readBin(con, "raw", n = max_sample_bytes), finally = close(con))
  detect_parser_sample(bytes,result,info$size>length(bytes),quote)
}

# Shared byte-sample detector: archive members never need temporary extraction.
detect_parser_sample <- function(bytes,result,sample_truncated,quote) {
  result$sample_bytes <- length(bytes)
  result$sample_truncated <- sample_truncated
  result$sample_sha256 <- digest::digest(bytes, algo = "sha256", serialize = FALSE)
  if (!length(bytes)) return(result)
  prefix <- function(values) length(bytes) >= length(values) && identical(bytes[seq_along(values)], as.raw(values))
  if (prefix(c(255,254,0,0)) || prefix(c(0,0,254,255))) {
    result$encoding <- list(status = "unsupported", method = "bom", value = if (prefix(c(255,254,0,0))) "UTF-32LE" else "UTF-32BE")
    result$message <- "UTF-32 BOM detected; this encoding is not supported."
    return(result)
  }
  bom <- if (prefix(c(255,254))) "UTF-16LE" else if (prefix(c(254,255))) "UTF-16BE" else if (prefix(c(239,187,191))) "UTF-8" else NULL
  encoding <- if (is.null(bom)) "UTF-8" else bom
  decoded <- NULL
  trimmed <- 0L
  # Only a truncated sample may end in a partial UTF-8 code point or UTF-16
  # surrogate. Never trim bytes from a complete file to conceal malformed input.
  for (tail in seq.int(0L, if (result$sample_truncated) 3L else 0L)) {
    if (tail && !is_incomplete_unicode_tail(bytes, tail, encoding)) next
    candidate <- if (tail) bytes[seq_len(max(0L, length(bytes) - tail))] else bytes
    decoded <- suppressWarnings(iconv(list(candidate), from = encoding, to = "UTF-8", sub = NA, toRaw = TRUE)[[1]])
    # iconv may optimise UTF-8 -> UTF-8 as a byte copy. Validate its output
    # explicitly instead of treating a non-NULL conversion as proof of validity.
    if (!is.null(decoded) && !any(decoded == as.raw(0)) && validUTF8(rawToChar(decoded))) { trimmed <- tail; break }
    decoded <- NULL
  }
  if (is.null(decoded)) {
    if (!is.null(bom)) {
      result$encoding <- list(status = "identified_but_invalid", method = "bom", value = bom)
      result$message <- "A BOM identifies the encoding, but the bounded sample does not decode cleanly."
    } else result$message <- "Encoding is ambiguous or contains NUL bytes; select it manually. Legacy encodings are not guessed."
    return(result)
  }
  result$encoding <- list(status = "detected", method = if (is.null(bom)) "valid_utf8" else "bom", value = encoding, trimmed_tail_bytes = trimmed)
  result$parser$encoding <- encoding
  text <- sub("^\ufeff", "", rawToChar(decoded))
  # A sample boundary is not EOF: a half-read record cannot disqualify another
  # separator and manufacture certainty. Keep only quote-aware terminated rows.
  if (result$sample_truncated) text <- complete_detection_prefix(text, quote)
  delimiters <- c(",", ";", "\t", "|")
  candidates <- lapply(delimiters, function(separator) {
    trial <- result$parser
    trial$delimiter <- separator
    tryCatch({
      records <- lexical_records(text, trial, 21L)
      widths <- lengths(records)
      consistent <- length(widths) >= 2L && widths[1] > 1L && all(widths == widths[1])
      list(value = separator, consistent = consistent, records = length(widths),
        columns = if (length(widths)) widths[1] else 0L)
    }, error = function(e) list(value = separator, consistent = FALSE, reason = conditionMessage(e)))
  })
  viable <- which(vapply(candidates, function(x) isTRUE(x$consistent), logical(1)))
  result$delimiter$candidates <- candidates
  if (length(viable) == 1L) {
    result$parser$delimiter <- delimiters[viable]
    result$delimiter$status <- "detected"
    result$delimiter$value <- delimiters[viable]
    result$delimiter$method <- "unique_consistent_quote_aware_candidate"
    result$status <- "detected"
    result$message <- "Encoding and separator detected from the bounded sample; manual overrides remain available."
  } else {
    result$status <- "partial"
    result$delimiter$status <- if (length(viable) > 1L) "ambiguous" else "unresolved"
    result$message <- "Encoding detected; separator is ambiguous, single-column or insufficiently supported. Verify the separator."
  }
  result
}

# Validate the suffix itself before allowing a truncated-codepoint retry. In
# particular FF, NUL and isolated UTF-16 low surrogates must never be discarded.
is_incomplete_unicode_tail <- function(bytes, trim, encoding) {
  if (trim > length(bytes)) return(FALSE)
  suffix <- as.integer(utils::tail(bytes, trim))
  if (encoding == "UTF-8") {
    first <- suffix[1]
    needed <- if (first >= 194L && first <= 223L) 2L else if (first >= 224L && first <= 239L) 3L else if (first >= 240L && first <= 244L) 4L else 0L
    if (!needed || trim >= needed) return(FALSE)
    if (trim > 1L) {
      if (any(suffix[-1] < 128L | suffix[-1] > 191L)) return(FALSE)
      second <- suffix[2]
      if ((first == 224L && second < 160L) || (first == 237L && second > 159L) ||
          (first == 240L && second < 144L) || (first == 244L && second > 143L)) return(FALSE)
    }
    return(TRUE)
  }
  if (!encoding %in% c("UTF-16LE", "UTF-16BE")) return(FALSE)
  odd <- length(bytes) %% 2L == 1L
  if (odd && trim == 1L) return(TRUE) # first byte of an unfinished code unit
  if ((!odd && trim != 2L) || (odd && trim != 3L)) return(FALSE)
  unit <- if (encoding == "UTF-16LE") suffix[1] + 256L * suffix[2] else 256L * suffix[1] + suffix[2]
  if (unit < 55296L || unit > 56319L) return(FALSE) # high surrogate only
  if (odd && encoding == "UTF-16BE" && !suffix[3] %in% 220:223) return(FALSE)
  TRUE
}

# Quotes are retained in the returned text; the strict candidate-specific lexer
# still validates their field placement. This pass only finds complete physical
# record boundaries, respecting doubled quotes and quoted multiline content.
complete_detection_prefix <- function(text, quote) {
  # Internal text has already been decoded to UTF-8. Mark it explicitly:
  # Windows native strings can count non-BMP code points as two units and
  # strsplit() then pads the token vector with phantom empty characters.
  Encoding(text) <- "UTF-8"
  chars <- strsplit(text, "", fixed = TRUE)[[1]]
  quoted <- FALSE
  last <- 0L
  i <- 1L
  while (i <= length(chars)) {
    ch <- chars[i]
    if (nzchar(quote) && ch == quote) {
      if (quoted && i < length(chars) && chars[i + 1L] == quote) { i <- i + 2L; next }
      quoted <- !quoted
    } else if (!quoted && ch %in% c("\r", "\n")) last <- i
    i <- i + 1L
  }
  if (last) substr(text, 1L, last) else ""
}

# Apply only supported components; preserve existing settings when evidence is
# unresolved. Evidence is scoped to immutable resource bytes, never filenames.
detect_registered_configuration <- function(repo, version_id, parsers, evidence = list(), resource_ids = NULL) {
  verified <- verify_input(repo, version_id)
  if (!verified$ok) stop("Input integrity verification failed before detection")
  resources <- verified$resources
  if (is.null(resource_ids)) resource_ids <- resources$resource_id
  if (!length(resource_ids) || any(!resource_ids %in% resources$resource_id)) stop("Unknown detection resource")
  for (rid in resource_ids) {
    resource <- resources[resources$resource_id == rid, , drop = FALSE]
    detected <- detect_parser(resource$owned_path, resource$original_name, quote = parsers[[rid]]$quote)
    if (detected$encoding$status == "detected") parsers[[rid]]$encoding <- detected$parser$encoding
    if (detected$delimiter$status == "detected") parsers[[rid]]$delimiter <- detected$parser$delimiter
    detected$resource_sha256 <- resource$sha256
    detected$detected_at <- utc_now()
    evidence[[rid]] <- detected
  }
  if (!verify_input(repo, version_id)$ok) stop("Input integrity changed during detection")
  list(parsers = parsers, evidence = evidence)
}

#' Detect the selected resource into a new configuration revision
#' @param repo Open repository handle.
#' @param config_id Exact latest configuration snapshot to extend.
#' @param resource_id Resource within that configuration's input version.
#' @param actor_id Explicit requesting operator label.
#' @param expected_workspace_revision Optional displayed lifecycle revision.
#' @return New configuration snapshot; existing snapshots remain unchanged.
#' @export
redetect_configuration <- function(repo, config_id, resource_id, actor_id, expected_workspace_revision = NULL) {
  current <- get_configuration(repo, config_id)
  membership <- assert_workspace_active(repo, current$version_id, expected_workspace_revision)
  rows <- list_configurations(repo, current$version_id)
  if (utils::tail(rows$config_id, 1) != config_id) stop("stale configuration; reload before detection")
  evidence <- if (is.null(current$parser_detection)) list() else current$parser_detection
  detected <- detect_registered_configuration(repo, current$version_id, current$parsers, evidence, resource_id)
  save_configuration(repo, current$version_id, parsers = detected$parsers,
    metadata = current$metadata, schema = current$schema, parser_detection = detected$evidence,
    expected_revision = current$revision, actor_id = actor_id, expected_workspace_revision = membership)
}
