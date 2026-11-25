# Ecological platform: local Shiny workspace

This R package implements local input registration, immutable configuration revisions and SQLite processing history, with a first Shiny interface for uploading files, configuring lexical previews and inspecting history. Scientific validators are not included yet. See the [approved workspace structure](../README.md), [storage contracts](docs/architecture/step1-storage.md) and [Shiny manual checks](docs/user-guide/shiny-workspace.md).

New CSV/TSV uploads automatically detect supported encoding and separator when evidence is unambiguous. Detected settings and evidence are saved in revision 1. Manual controls remain available; **Rileva formato** redetects an already registered file into a new revision. Ambiguous legacy encodings and competing separator candidates are explicitly flagged for review. See [automatic detection](docs/user-guide/parser-detection.md).

The next approved slice (Task 2A) supplies versioned validation definitions,
source-scoped mapping declarations and typed result contracts, stored in immutable
configuration snapshots. It executes no validation rules and adds no validation UI.
See [contract architecture](docs/architecture/validation-contracts.md) and
[manual contract checks](docs/user-guide/validation-contracts.md). This increment
has been reviewed and explicitly approved by the user for commit and push.

## Launch the interface

Uploaded source versions can now be removed reversibly from active work and
restored from **Rimossi**. Files and history remain stored; removal does not free
disk space. See [removal and manual checks](docs/user-guide/workspace-removal.md)
and [schema v2 contracts](docs/architecture/workspace-lifecycle.md). Stop older
app processes before opening an existing runtime with this version: it upgrades
schema v1 automatically after making a verified backup.

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

The user approved publication of reversible workspace removal, including its
code, tests and documentation. See the [removal verification summary](docs/verification/2026-11-24-workspace-removal.md)
for executed checks, scope and operational limits.

The user approved publication of input registration, the Shiny interface and automatic format detection, including tests and documentation. See the [verification summary](docs/verification/2026-11-24-foundation-shiny-detection.md) for scope and executed checks. Generated evidence and runtime data remain local; future implementation increments still require their own approval.

## Step 2B: complete reading and independent prerequisites

The read-only services read_validation_tables() and
assess_validation_prerequisites() prepare complete populations independently of
the Shiny preview. They preserve source strings and descriptor key indices,
reject stale mapping schemas, and separate linkage from date prerequisites.
ready denotes prerequisite readiness; zero rows have been scientifically checked.

See [architecture](docs/architecture/full-table-prerequisites.md),
[manual checks](docs/user-guide/full-table-prerequisites.md) and
[verification](docs/verification/2026-11-25-full-table-prerequisites.md).
The user approved publication of this increment on 25 November 2026.

## Missing-information clarification

The Informazioni mancanti tab asks for dataset-specific prerequisites and shows
unapproved suggestions. Review an exact answer, then approve it to create one
versioned configuration with source-bound provenance. Cancelling saves nothing.
Independent fields remain available; an explanatory source-repair note leaves
its blocked prerequisites pending.

See the [operator guide](docs/user-guide/clarifications.md),
[service architecture](docs/architecture/clarifications.md) and
[verification results](docs/verification/2026-11-25-clarifications.md).
The user approved publication of the implementation on 25 November 2026.

## ZIP collections without a descriptor

Ordinary ZIPs with CSV/TSV/TXT members are now read independently when meta.xml is
absent. Per-member format/header settings and user-declared table relationships
use the clarification approval workflow and versioned configuration receipts.
Ignored sidecars are listed without execution. Proposed counts remain distinct
from confirmed populations. Present invalid descriptors are not bypassed.

See [operator guide](docs/user-guide/plain-zip.md),
[architecture](docs/architecture/plain-zip.md) and
[verification](docs/verification/2026-11-25-plain-zip.md).


Publication approval (25 November 2026): the user approved committing and pushing
Step 2B, clarification workflow and ZIP support without meta.xml to martinaPulieri/ecodata.
Final combined verification: 772 assertions, zero failures/errors/warnings/skips; installed-package Status: OK.

## Step 2C: exact linkage

The read-only run_linkage_validation() service now executes the declared/
approved archive relationship checks with typed per-measurement outcomes,
findings, coverage and multiplicity. compare_linkage_key_scope() provides a
separate provisional ID/namespace diagnostic without adopting a mapping.
The supplied OBIS snapshot does not require dataset_id + id to obtain unique
targets; its real settings and semantic mapping remain subject to approval.

See [verification](docs/verification/2026-11-25-linkage-engine.md),
[manual guide](docs/user-guide/linkage-engine.md) and
[architecture](docs/architecture/linkage-engine.md).
The user approved publication of this implementation on 25 November 2026.


Publication approval (25 November 2026): the user approved Step 2C code, tests,
updated plan and documentation for commit/push to martinaPulieri/ecodata.
Verified suite: 928 assertions with zero failures/errors/warnings/skips; installed-package Status: OK.
