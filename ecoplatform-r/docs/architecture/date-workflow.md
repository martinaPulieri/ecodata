# Approved date workflow

`workspace_server` saves a complete reading revision, explicitly records parser
confirmation, and generates its preview with the newly returned configuration ID.
Preview state is retained when the browser acknowledges that revision and is
cleared on a different source/configuration or removal. Archives keep descriptor
settings. No SQLite schema migration is added beyond Task 2E's schema v3.

`workspace_date_information` owns a session-scoped supervised callr preparation
process. The process opens/closes its own repository connection and returns
`prepare_date_information`: full-table prerequisites plus technical per-column
format suggestions/examples. Polling is nonblocking; context changes or session
end stop/discard the old preparation. Duration is unknown, so the progress bar is
indeterminate. The existing full-reader quotas still apply.

`save_date_declarations` validates the exact latest active context, source hashes,
column structure and supported patterns before appending a configuration. It
preserves other resources' mappings and replaces mappings for the displayed table
scope only in the new revision. Explicit selected mapping IDs are frozen in
configuration metadata so descriptor or suggested dates cannot silently expand
the guided run. The UI supplies neutral technical provenance; users do not enter a
semantic date role or evidence. Run submits only the dates family to the existing
persistent worker. Repeated/stale clicks cannot queue another assessment.

The optional `declared_pattern` field extends date mappings without changing
historic canonical payloads: it is omitted when NULL. `classify_date_values`
filters candidates to the exact declared pattern before classification. Old
unrestricted mappings and saved results remain valid. Format inference is
separate from validation and never changes source values.

The guided catalogue is now 1.1, adding timestamp-no-zone separately from
timestamp-z. The matcher uses the frozen timezone declaration to require either
no suffix or literal Z; no timezone is inferred. The UI names detected formats
even when a different historic declaration remains selected. Validation activity
uses persisted run/family stages and an indeterminate bar, limited to pending runs.
