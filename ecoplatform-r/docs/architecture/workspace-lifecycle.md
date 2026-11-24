# Workspace lifecycle and schema v2

Membership belongs to a source version, including all resources. No event means
active at revision zero. workspace_lifecycle_events appends state, monotonic
revision, actor, UTC time, optional reason and unique request ID/fingerprint.
UPDATE/DELETE triggers protect this audit trail, like the existing source tables.
No existing immutable table or file is deleted or rewritten.

repository_workspace_lifecycle.R exposes get_workspace_state(),
list_workspace_inputs(), list_workspace_events() and set_workspace_state().
list_inputs() retains its historical, unfiltered contract. The workspace list
projects the highest event revision, with active/removed/all filters.

set_workspace_state() reserves the writer with BEGIN IMMEDIATE, resolves an
idempotent request, checks the displayed lifecycle revision and transition,
checks queued/running operations, then appends. Reusing the same request with a
different payload is rejected. An identical retry returns its original event,
even if another lifecycle event has subsequently occurred.

New configuration writes and operation submissions check active membership
inside their own writer reservation. A displayed lifecycle revision also rejects
remove/restore cycles (ABA). Detection captures membership before parsing and
passes it through the final configuration save. Existing operation request IDs
remain historical lookups after removal; they never start new processing.
Low-level inspect_input()/get_input()/verify_input() remain read-only audit APIs
for retained inputs. Actor labels are trusted local provenance, not authentication.

service_workspace_lifecycle.R wires confirmation, cancellation, Undo, restore,
read-only Removed view and polling. mod_workspace.R binds lifecycle revision into
configuration-form tokens and passes it to write services. A confirmation button
carries its own unique request token; delayed events cannot confirm a newer
dialog. Removing the current input clears its cached preview and refreshes choices.

open_repository() supports schema 2. Registered migrations initialise 0→1→2 or
upgrade 1→2 in one writer transaction. Existing v1 databases are backed up first
through a separate read-only connection while the writer reservation excludes
concurrent writers. The backup is verified and includes committed WAL contents.
Fresh databases need no pre-upgrade backup. Migration failure rolls back schema
and user_version; managed input files are unaffected. Close older app processes
before upgrading a shared runtime: an old process already holding a v1 connection
cannot enforce v2 membership rules. Downgrading schema v2 to v1 is not supported;
retain the verified pre-upgrade backup and the separate managed input files.

Tests exercise multi-file/version isolation, restart, byte/hash/history retention,
idempotent retries, pending work, stale/ABA writes, concurrent writer races,
v1 migration/backup and failed future migration rollback, plus Shiny handlers.
