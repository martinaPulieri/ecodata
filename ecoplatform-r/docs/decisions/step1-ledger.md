# Step 1 implementation ledger

Plan: docs/superpowers/plans/2026-11-23-ecological-platform-validation-first.md, Task 1 only.

- 2026-11-24: resumed existing dedicated checkout on feat/input-history-foundation, based on 317ce5948df2b16188e66fe8c9afd3909f7f12bb. No prior application code exists in this checkout. No commits or pushes authorised for this step yet.
- Ruling: retain the approved flat R/ layout from README instead of the earlier plan's nested sketch; standard package loading then works without custom source loaders.
- Ruling: implement only the first step. Scientific validation, Shiny and decisions on findings belong to step 2 or later. Schema profiles describe prerequisites but do not execute rules here.
- Ruling: explicit configuration revisions require the previous revision number (NULL means first revision only), including across independent connections.
- Ruling: restart exposes pending operations without automatically interrupting another active worker. A user/worker explicitly records interruption; a future scheduler will own worker liveness.
- Ruling: database storage is append-only for source/configuration/operation records. Operation states are projections of append-only events.
- Ruling: preview inspection is bounded and never a full validation result. Default parser choices are recorded assumptions, not inferred scientific meaning.
- Pre-flight: registration produces version/resource IDs; configuration binds them; inspection and history consume exact version/configuration pairs. No cross-task functions are needed to complete this foundation.
- Ruling: keep the existing repository's Apache-2.0 licence for the new package; no independent MIT licence is introduced.
- Independent review: one fresh-context reviewer found malformed quote/CRLF handling, header-only record IDs, repeated archive references/descriptor syntax, migration locking and backup publication races. Added regression tests before corrections. No reviewer findings are deferred.
- Review fixes: replaced permissive read.table preview parsing with a bounded strict lexical reader; preserved embedded CRLF and escaped quotes; empty tables now have no record IDs.
- Review fixes: validated complete resolved archive reference sets, exact header counts and declared record separators; repeated members cannot bypass decompression bounds.
- Review fixes: re-read schema state under BEGIN IMMEDIATE; take pre-migration snapshots through a separate read-only connection while writers are excluded; bounded WAL negotiation handles simultaneous first opens.
- Review fixes: reserve private backup staging and exclusively publish only a verified, closed snapshot. Closed source handles are checked before the native backup API; the original regression probe exposed a native crash with a closed source, now prevented.
- Ruling: backup publication requires hard-link support; unsupported filesystems return an explicit error rather than risk an overwrite. Crash-left staging directories require explicit inspection.
- Ruling: add explicit UTF-16LE/BE decoding after the supplied Venice example demonstrated that encoding. Defaults remain UTF-8 and no scientific role/date/number inference is introduced. Also corrected the tab delimiter's whitespace validation; regression tests cover TSV and UTF-16.
