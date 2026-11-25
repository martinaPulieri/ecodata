#' Freeze an active source configuration for future validation
#'
#' Read-only: verifies bytes and captures declarations/catalogues but creates no
#' operation and executes no checks. Suggested mappings remain unconfirmed.
#' @param repo Open repository handle.
#' @param config_id Exact immutable configuration containing a validation_spec.
#' @return JSON-compatible context with resource hashes, configuration hash,
#'   workspace revision, complete specification and its own canonical hash.
#' @export
freeze_validation_context <- function(repo, config_id) {
  config <- get_configuration(repo, config_id)
  membership <- assert_workspace_active(repo, config$version_id)
  if (is.null(config$validation_spec)) stop("Configuration has no validation specification")
  verified <- verify_input(repo, config$version_id)
  if (!verified$ok) stop("Input integrity verification failed")
  resources <- verified$resources
  validate_validation_spec(config$validation_spec, config$version_id, resources$resource_id)
  result <- list(contract_version = "validation-contracts-1.0", version_id = config$version_id,
    config_id = config_id, config_hash = config$context_hash, workspace_revision = membership,
    resources = lapply(seq_len(nrow(resources)), function(i) as.list(resources[i,
      c("resource_id", "sha256", "original_name", "size_bytes"), drop = FALSE])),
    validation_spec = config$validation_spec)
  result$context_hash <- hash_text(json_text(result))
  contract_copy(result)
}

validate_frozen_context <- function(context) {
  contract_fields(context, c("contract_version", "version_id", "config_id", "config_hash",
    "workspace_revision", "resources", "validation_spec", "context_hash"), "frozen context")
  if (!identical(context$contract_version, "validation-contracts-1.0")) stop("Unsupported frozen context version")
  scalar_text(context$version_id, "context version_id")
  scalar_text(context$config_id, "context config_id")
  digest_field <- function(value, name) {
    scalar_text(value, paste("context", name))
    if (!grepl("^[a-f0-9]{64}$", value)) stop("Invalid context ", name)
  }
  digest_field(context$config_hash, "configuration hash")
  digest_field(context$context_hash, "hash")
  contract_count(context$workspace_revision, "context workspace revision")
  if (!is.list(context$resources) || !length(context$resources) || !is.null(names(context$resources))) stop("Invalid context resource array")
  for (resource in context$resources) {
    contract_fields(resource, c("resource_id", "sha256", "original_name", "size_bytes"), "context resource")
    scalar_text(resource$resource_id, "context resource_id")
    scalar_text(resource$original_name, "context original_name")
    digest_field(resource$sha256, "resource hash")
    contract_count(resource$size_bytes, "context resource size")
  }
  ids <- vapply(context$resources, function(x) x$resource_id, character(1))
  if (anyDuplicated(ids)) stop("Duplicate context resource identity")
  payload <- context; payload$context_hash <- NULL
  if (!identical(context$context_hash, hash_text(json_text(payload)))) stop("Frozen context hash mismatch")
  validate_validation_spec(context$validation_spec, context$version_id, ids)
  invisible(context)
}
