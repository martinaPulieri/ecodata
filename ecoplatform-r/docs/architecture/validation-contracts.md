# Validation definitions, mappings and result contracts (Task 2A)

This increment defines the data that later validation will consume and produce.
It executes no linkage/date checks and adds no Shiny validation controls. Actual
table reading and source-schema prerequisites are Task 2B; matching/check engines
are Tasks 2C/2D; dedicated result persistence and UI are Task 2E. Schema remains v2.

## Versioned definitions

`validation_rules()` loads `inst/rules/linkage-dates-1.0.json`: PRE-01, LNK-01–08,
TMP-00–03 and TMP-08, including RF references, prerequisite dependencies,
mandatory/supplemental flags and diagnostic severity. Linkage errors use `error`,
warnings `warning`, coverage `information`. Date classifications and technical
execution states have no implied finding severity. The historical profile
catalogue's `critical` vocabulary is unchanged; no integration eligibility policy
or automatic severity conversion is introduced.

`date_patterns()` loads `inst/rules/date-patterns-0.1.json`. It is provisional and
contains ten explicit pattern definitions: year-first and year-last dates,
year/year-month, the documented Z timestamp, a year-first interval and split
numeric components. Single-field examples have fixed displayed widths; split
day/month allow one or two digits and year four. Natural language, two-digit years
and unlisted timestamp/timezone variants require a future catalogue extension.
No calendar-range logic, canonical conversion, interval ordering, user interval
or EML coverage is implemented. Catalogue readers reject unknown versions.

Each new specification embeds complete catalogue snapshots and canonical JSON
SHA-256 hashes, plus the enabled rule/pattern IDs. Installed catalogue files must
not be edited under an existing version. Add a new version and retain old versions
when extending policy; the current implementation supports the versions above.
Specification/context hashes are reproducibility checks, not authenticated signatures.

## Mapping declarations and source identity

`new_validation_table()` declares source version, resource, optional archive member
and original ordered headers. Standalone IDs are `resource_id:table`; member IDs
are `resource_id:member`. Logical data rows use `table_id:row:N`, matching existing
preview identity conventions. Header/column positions are **zero-based**; logical
data-row numbers are **one-based**, excluding the header. Duplicate/empty original
headers are retained and are disambiguated by position.

`new_date_mapping()` binds a role to `value`, or to explicitly named `day`, `month`
and `year` positions. Physical order does not assign roles. It stores the original
header at each position, mapping ID, provenance source, operator, evidence,
confirmation and optional documented date order/evidence. Suggested mappings
cannot claim confirmation; construct a new user mapping after explicit approval.
Different date roles may coexist on one table. Mapping IDs must be unique within
one source specification. Nonempty date-order evidence is required when order is
declared; split roles already identify the components.

`new_linkage_mapping()` declares distinct core/extension members of the **same
archive resource and source version**, with descriptor core-ID/reference positions.
Index 0 is valid. The core's `occurrenceID` field is not substituted for its key.
Both member declarations, their headers, columns and provenance are retained.

These are declarations, not certificates that a source has those columns. Contract
validation checks internal shape, positions within the declared schema, consistent
table identities, and registered version/resource ownership at configuration save.
Task 2B must compare the declarations against actual members/headers and establish
descriptor/profile usability before any dependent check can run.

## Configuration persistence and frozen context

`new_validation_spec()` collects mappings, snapshots and enabled IDs.
`save_configuration(..., validation_spec=spec)` appends it in the existing immutable
configuration JSON. No new table/migration is necessary. Omitted/NULL specification
inherits the previous revision under the same writer reservation as the stale
revision check. An explicit empty specification clears mappings in a new revision.
The previous payload hash is verified before inheritance, so corrupted history
cannot be propagated into a newly hashed snapshot. Older revisions and legacy
payload hashes remain unchanged. Legacy configurations
without a specification stay without one; retrieval invents no validation metadata.
Existing parser edits, redetection and profile confirmation preserve the snapshot.
Removed-source and stale-configuration/workspace guards remain in force.

`freeze_validation_context()` verifies registered bytes and captures exact source,
configuration/hash, resource manifests, workspace revision and complete specification
in portable hashed JSON. It creates no operation. Result constructors consume this
frozen context, not live/latest defaults. Future submission must check its workspace
revision again atomically; constructing a context is not authorisation to execute.

## Typed results and counting

- `new_check_result()`: independent applicability, execution state, population,
  evaluated count, coverage and reason. Unknown populations are NULL. Inapplicable
  or prerequisite-missing checks are not_started with zero evaluated rows.
- `new_date_result()`: one mapping/row, original component strings, provenance,
  observed widths, status, candidate definitions, missing components and pattern
  version. Recognised requires one candidate; ambiguous requires at least two.
  Suggestions only permit explicit not_evaluated records with a reason.
- `new_linkage_result()`: exactly one extension-row outcome; one target for linked,
  multiple targets for ambiguous, none for missing/unresolved/not evaluated.
- `new_validation_finding()`: separate diagnostic with severity and one or many
  row targets bound to a confirmed declared linkage and its core/reference column.
  A repeated-key group requires at least two rows with the exact same nonmissing
  key; per-row diagnostics require one appropriate target. An ambiguous choice of
  relationship requires an explicit mapping_id. Coverage groups remain separate.

Constructors validate record consistency; callers supply classifications. They do
not recognise date strings, determine matches or prove scientific correctness.
For example a caller may record `2020-02-30` with `ymd-dash` without claiming that
date exists. Strings such as `001`, `NA`, blanks and tabs are preserved; native R
NA values are rejected where original text is required. Empty/whitespace detection
is used only for missing-value consistency, not identifier trimming or comparison.

All state/provenance labels must be explicit exact scalar values: NULL, vectors
and abbreviations cannot invent a valid state. Positional inputs (headers, row
numbers, original-value arrays) discard incidental R names before serialisation.
Counts and row positions are bounded to 2,147,483,647 to preserve exact JSON/R
identity; larger populations are unsupported by this contract version.

Portable contexts independently validate required identities, resource manifest
fields/digests, contract version and their canonical hash. A digest alone is not
a structural check. Imported row records are reconstructed against the expected
context/mapping before summarisation, rejecting contradictory source/config/table,
rule, locator, candidate or provenance metadata even if their hash was recomputed.

Records carry context/configuration/rule versions and canonical hashes. Per-mapping
summary functions reject another context, altered record hashes, duplicate rows,
out-of-population rows and missing records. Every declared row must have one result,
including explicit not_evaluated rows. Candidate/finding counts never inflate the
mutually exclusive row totals. Group summaries are called separately per mapping;
zero-row populations return zero counts.

See [manual demonstration](../user-guide/validation-contracts.md). Dedicated result
tables, review decisions, full-table validation and browser acceptance remain later
increments. The existing Shiny upload/preview workflow is retained.
