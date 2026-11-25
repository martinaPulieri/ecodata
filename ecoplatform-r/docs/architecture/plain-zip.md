# Ordinary ZIP reader and approval contracts

This increment extends Step 2B and the clarification workflow. SQLite stays v2.
No scientific matching, date classification, ingestion connector or report is added.

## Dispatch and safe reading

read_validation_archive() and inspect_archive() search case-insensitively for
meta.xml. Exactly one descriptor uses the established descriptor route. Multiple
or malformed descriptors remain explicit failures. Only absence activates
read_plain_archive()/inspect_plain_archive().

The fallback inventories CSV/TSV/TXT members and ignored sidecars. It reuses
check_archive_entries() before opening unz() streams. No file extraction or
sidecar instruction execution occurs. Existing 200 MiB archive/1,000 entry guards
and 50 MiB default per-table full-read quota apply. Row/field quotas, cancellation
and resource integrity/lifecycle guards are unchanged. Each member fails alone.

detect_parser_sample() is the shared bounded byte-sample algorithm used by
standalone files and archive members. BOM/valid UTF-8 and quote-aware separator
evidence can suggest settings; filename suffix alone does not establish a parser
or header presence. Legacy encodings are not guessed.

Plain tables retain archive_mode=plain_zip, proposed_setting, detection evidence
and settings_pending. They retain declaration=NULL: no fake Darwin Core
descriptor is created. Before settings approval, loaded_rows reports a candidate
count while population_count remains NULL; prerequisites are gated.
Per-member actual schemas retain original decoded headers or generated column_N
labels for approved headerless data. Values and logical record locators retain
the same lexical-preservation semantics as Step 2B.

Bounded previews read at most the configured byte prefix per member, validate
Unicode suffix trims and retain only terminated quote-aware logical records.
A truncated byte suffix cannot become a field value or data-row locator.
Preview provenance says preview_only and never substitutes for a complete scan.

## Configuration and approval

Optional archive_settings is a named resource -> member -> {parser, header}
snapshot. save_configuration() inherits NULL under BEGIN IMMEDIATE, retaining
legacy snapshot hashes and existing settings. Overrides are validated against
safe, actual members of archives without a descriptor. Unchanged inherited
resources are not reopened, so a damaged sibling cannot block an intact target.

An archive_parser question binds exact source hash/resource/member and configuration.
The existing server draft/review/approve service records a clarification receipt.
The reader accepts approval only when the source, member and exact applied setting
match. Merely inserting settings through a low-level API does not invent a UI
approval. Current settings differing from an old receipt remain pending.

An archive_linkage answer includes both table IDs and key positions. The service
resolves actual schemas inside the same archive and constructs source=user
mappings only after explicit approval. Identical filenames/headers across different
resources cannot share approval. Existing replacement planning is shown in the
review dialog before competing/stale mappings are retired in the new revision.

plain_archive_linkage_prerequisites() evaluates each resource separately.
Approved semantics still wait on their own parser/schema/readability prerequisites;
an unresolved relationship in another archive cannot reopen an approved mapping.
Dates remain independent. Linkage contracts currently support one key column on
each side; a composite-key matcher is outside this slice. Operators must not
declare a single-column relationship when a compound scope is required.

The resource-level detector's archive_declared status is not a standalone-parser
uncertainty: descriptor or per-member prerequisites control archive readiness.

## Verification

New test files cover plain ZIP and Shiny workflows, member approvals/inheritance,
headerless UTF-16, exact text, quotas/cancellation, ignored sidecars, bounded
previews, malformed/present descriptors, multi-resource isolation, stale settings,
upload-service detection, incomplete values and surrogate-pair boundaries.

A fresh read-only review reproduced five issues. Regression tests failed first,
then the single fix pass corrected uploaded-ZIP readiness, complete-record prefix
previews, sibling question scoping, unchanged-sibling validation and Unicode tails.
Full regression and installed-package evidence are recorded in the verification
report. A real OBIS demonstration leaves all research answers pending.

## Full-scan quotation evidence and performance

For a member without explicit saved settings, a failed quoted interpretation can
be retried with literal quotes. The alternative is retained only if it produces
a readable complete/limited table, is labelled needs_review and remains subject
to exact approval. Saved settings are never overridden. The rejected reason and
new proposal are recorded separately from the original byte-sample evidence.

The real OBIS run exposed quadratic UTF-8 field extraction in the shared strict
lexer. Field values now slice already-tokenised characters rather than repeatedly
scanning the entire source prefix through substr(). Quote grammar, Unicode,
whitespace and logical record handling remain unchanged and are regression-tested.
A local 128 KiB OBIS sample (105 records) measured 27.36 seconds before and
1.36 seconds after, with substr accounting for 94.49% of sampled self time before.
These are local diagnostic measurements, not a production throughput guarantee.

## Explicit UTF-8 character identity on Windows

The real OBIS file also exposed a Windows/R native-string edge case for non-BMP
Unicode. The decoded byte string was valid UTF-8 but unmarked; native character
counting treated these symbols as surrogate units, and strsplit() padded its
result with empty character tokens. This produced a phantom last record.
The lexer and quote-aware prefix scanner now explicitly mark their already
decoded text as UTF-8 before tokenisation. Source bytes and decoded values are
unchanged. A BOM-free non-BMP regression failed first and then passed.
The OBIS diagnostic showed 40 padding tokens before and none after this mark.
This correction is separate from optional quotation-convention suggestions.
