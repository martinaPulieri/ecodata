# Clarification services and configuration provenance

The clarification workflow is an extension to Step 2B preparation. It executes
no linkage matching or date recognition and creates no validation results or
operation-history rows. SQLite remains schema v2. Source repair uses the existing
immutable registration flow rather than editing registered files.

## Service boundaries

prepare_clarifications(repo, version_id, config_id) reads exact registered input
and returns clarification-questions-1.0: complete preparation, independent
prerequisites, typed requests, reasons, dependencies and unconfirmed proposals.
A request is scoped to resource hash, table, exact configuration/hash and workspace
revision. A stable question key associates earlier explanatory answers; the
question ID also binds the particular configuration and reason.
Historical snapshots may be inspected; writes require the latest active revision.

preview_clarification_answer() rebuilds requests from server-side source context,
validates a typed answer and returns clarification-draft-1.0. The draft carries
raw and normalized values, operator/evidence, exact question and proposed mapping
replacements, sealed with a canonical JSON digest. It performs zero writes.
Schemas/headers are read from the registered source, never trusted from form data.

approve_clarification_answer(..., approved=TRUE) requires explicit approval,
checks the seal, latest revision and lifecycle, re-reads source integrity/questions,
revalidates the exact normalized answer and replacements, then appends one
configuration through save_configuration's BEGIN IMMEDIATE revision guard.
Client controls are not read again at approval. Local actor labels are provenance,
not authentication. The digest detects accidental changes; it is not an access
control or cryptographic signature.

## Configuration receipts

Optional clarifications contains clarification-answer-1.0 receipts:
question/key and exact prior config ID, immutable version/resource/hash,
question/evidence, supplied and applied values, explicit approved=TRUE,
operator, UTC approval time and superseded mapping references.
Legacy configurations remain unchanged and do not gain artificial approvals.
NULL receipts inherit atomically. Parser detection entries also inherit on
omission (including an explicit empty set of updates), so unrelated configuration
edits cannot erase unresolved format evidence.

An approval applies a user date mapping or parser snapshot. Linkage mappings now
retain source=descriptor (legacy default) or source=user for explicit supplied
missing keys. Only a genuinely absent descriptor id/coreid can be supplied;
ambiguous, invalid and out-of-range keys require source repair even for a saved
user mapping. Known declared keys remain authoritative.

Competing linkage mappings for the same extension and mappings with conflicting
old schemas are listed for explicit replacement in the review dialog. The new
revision retires these obsolete mappings while preserving independent valid
mappings and rule/pattern snapshots. Historical revisions retain the old mappings.
Uncovered date candidates continue to appear after an independent role is approved.

A parser approval is valid for the exact current settings and resource hash.
Changing settings cannot reuse a different parser approval. Failed integrity
permits only an explanatory source-repair note, never technical mapping/parser
approval for changed bytes. A source-repair answer remains awaiting_source and
does not promote readiness. Configuration writes protect revision/lifecycle
atomically; registered source integrity is checked before/after bounded reading.
There is no OS lock protecting files from a malicious concurrent external writer.

## Shiny module

workspace_clarifications() owns per-session questions/drafts and renders the
Informazioni mancanti tab. Questions are generated only on an explicit button.
The review modal displays the exact server-held values and replacements.
Cancel discards the draft; approve checks context and operator again.
The parser form remains reactive while hidden so its existing form token tracks
configuration changes made on the clarification tab.
No reactive approval writes occur when merely choosing a suggestion or field.

Reads are synchronous and bounded by Step 2B quotas; large inputs may keep this
local preparation UI busy. Worker orchestration and durable scientific operations
remain Task 2E. No external messages or AI services are invoked.

## Verification locations

tests/testthat/test-clarifications.R exercises services, integrity, evidence
inheritance, independent mappings, descriptor conflicts, replacements, version
provenance, restart and replay. test-shiny-clarifications.R exercises review/
cancel/approval and context/operator guards using the real SQLite repository.
tools/manual-clarifications.R demonstrates real-data questions without approving
unknown semantics, plus explicit synthetic approval. Generated R help documents
all three new APIs and the compatible configuration/linkage parameters.
