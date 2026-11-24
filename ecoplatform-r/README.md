# Ecological platform: local Shiny workspace

This R package implements local input registration, immutable configuration revisions and SQLite processing history, with a first Shiny interface for uploading files, configuring lexical previews and inspecting history. Scientific validators are not included yet. See the [approved workspace structure](../README.md), [storage contracts](docs/architecture/step1-storage.md) and [Shiny manual checks](docs/user-guide/shiny-workspace.md).

New CSV/TSV uploads automatically detect supported encoding and separator when evidence is unambiguous. Detected settings and evidence are saved in revision 1. Manual controls remain available; **Rileva formato** redetects an already registered file into a new revision. Ambiguous legacy encodings and competing separator candidates are explicitly flagged for review. See [automatic detection](docs/user-guide/parser-detection.md).

## Launch the interface

From this directory, run `Rscript --vanilla tools/launch-shiny.R`, then open http://127.0.0.1:8791. ECODATA_PORT can select a different free local port; ECODATA_RUNTIME_ROOT selects persistent local, non-synchronised storage. Each browser session owns its SQLite connection. The exported `run_app()` and launcher consistently configure the upload transport limit; scientific validation remains a later increment.

## Setup

Use R >= 4.4.0. `renv.lock` records the dependencies used for verification. From this directory, install renv once and restore the project dependencies:

```r
install.packages("renv", repos = "https://cloud.r-project.org")
renv::restore(project = ".", lockfile = "renv.lock", prompt = FALSE)
```

For an already prepared development library, set ECODATA_R_LIBRARY to its path; the scripts prepend it without modifying other libraries. No project-wide .Rprofile is installed by this increment.

## Automated checks

Run in this directory:

```text
Rscript --vanilla tools/test-step1.R
Rscript --vanilla tools/check-step1.R
```

The check script stages package inputs, then runs `R CMD build` and `R CMD check --no-manual`, saving logs under evidence/step1/. The package has no compiled application code. Tests use temporary local runtime directories and real SQLite, including two independent R processes for concurrency checks, with synthetic inputs and no live reference services. See [manual acceptance](docs/user-guide/manual-step1.md) for inspectable examples.

## Minimal use in R

```r
pkgload::load_all(".")
repo <- open_repository() # local OS application-data directory, outside Dropbox
input <- register_input("/absolute/path/to/input.csv", list(title = "My input"), repo)
config <- save_configuration(repo, input$version_id, actor_id = "reviewer")
preview <- inspect_input(input$version_id, config$config_id, repo)
print(preview)
close_repository(repo)
```

Default parser choices are explicit assumptions; edit the configuration when needed. A complete edit supplies all intended fields and the current expected_revision. Never interpret `ready` inspection status as scientific validity or acquisition completeness.

The low-level register_input()/save_configuration() example above keeps explicit defaults. The Shiny upload service register_uploaded_inputs() adds automatic detection; it never rewrites existing configurations in the background.

Run `Rscript --vanilla tools/manual-step1.R` for a complete synthetic example with two revisions, lifecycle events, restart and backup. The script prints the created runtime path and saves evidence there. All source code functions have generated R help pages, for example `?register_input`, `?save_configuration` and `?submit_operation`.

## Review status

The user approved publication of input registration, the Shiny interface and automatic format detection, including tests and documentation. See the [verification summary](docs/verification/2026-11-24-foundation-shiny-detection.md) for scope and executed checks. Generated evidence and runtime data remain local; future implementation increments still require their own approval.
