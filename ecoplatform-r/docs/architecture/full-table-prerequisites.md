# Full-table preparation and independent prerequisites (Step 2B)

This slice adds two read-only R services: read_validation_tables() and
assess_validation_prerequisites(). It leaves the Shiny preview unchanged.
A preview contains at most its configured sample; it is never used as the
population for validation. No identifier matching, date recognition,
scientific pass/fail, results migration or validation UI is provided here.

## Reading contract

The reader takes an exact active version_id and config_id, checks that they
belong together and verifies source integrity before and after reading.
Lifecycle revision checks reject removal/restoration races. It creates no
SQLite operations, saved mappings, configurations or results. SQLite stays v2.

Standalone CSV/TSV uses the saved technical parser. DwC-A uses meta.xml per
member: encoding, delimiter, quoting, LF/CR/CRLF separator and zero/one header
line. Headerless columns receive generated column_N labels and carry
header_present=FALSE. Unsupported settings remain explicit limitations.
Decoded values stay character strings: no trimming, numeric/date conversion,
blank replacement or literal-NA conversion. Leading zeros, duplicate headers
and quoted newlines are preserved. Record locators use logical data-row
numbers (starting at 1), excluding the header; they are not physical line numbers.

The validation-preparation-1.0 structure carries exact configuration/hash,
resource hashes, declarations, table identity, schema, data, record_ids,
loaded_rows, population_count and status. Only complete tables have a known
population_count (including zero). limited, cancelled, unreadable and unsupported
never certify population coverage. A row-limited prefix can be returned with an
unknown population; other technical failures discard partial data.

Default per-table quotas are 50 MiB, 1,000,000 data rows and 5,000,000 decoded
fields including headers. The reader is bounded in-memory, not streaming.
Existing archive entry/path/collision/expansion protections apply; meta.xml is
bounded to 1 MiB, DTD/entities are rejected and network XML access is disabled.
Only the supported DwC text element namespace is accepted. Cancellation is
cooperative at resource/member boundaries and periodically during lexical
scanning; it does not interrupt every OS/decompression/XML operation.

## Independent prerequisite contract

validation-prerequisites-1.0 returns:
- PRE-01 table readability outcomes;
- LNK-01 relationship prerequisites;
- TMP-00 outcomes per date mapping and unconfirmed candidates.

ready means eligible for a later check. scientific_rows_evaluated is always
zero; scientific_checks_executed is FALSE. No coverage percentage or quality
summary is inferred from these prerequisites.

Linkage needs one declared Occurrence core and a supported MeasurementOrFact
or OBIS ExtendedMeasurementOrFact extension. The descriptor id and coreid
indices control keys (zero-based), independently of occurrenceID. Both members
must be complete and indices must fit actual columns. Saved mappings must
be confirmed and match actual table identity, headers, positions and descriptor
keys. An unusable extension affects linkage, while core date preparation continues.

Date prerequisites need a usable descriptor eventDate field or a confirmed
explicit mapping. A saved descriptor mapping must retain its eventDate role
and actual declared position. User mappings may define other date roles and
split day/month/year components in any order. Several mappings can coexist.
Saved mappings take precedence for their covered positions; other descriptor date fields remain independent. Stale headers are rejected. Duplicate eventDate positions are ambiguous and cannot produce duplicate ready mappings.
Header/value candidates remain source=suggested and confirmed=FALSE and
require operator confirmation. No date order or semantic role is inferred.
Candidates inspect up to eight nonblank values per column; this is suggestion
evidence, not a population assessment or pattern-recognition result.

Unsafe/unsupported descriptors cannot establish declarations. Readable members
with technical errors are assessed independently; a bad key declaration does not
block an otherwise usable date declaration, and a bad date index does not block
otherwise usable keys.

These structures are ephemeral preparation objects, not persisted Step 2A
quality result records. Descriptor-derived mappings retain member/hash evidence
but do not silently change versioned configuration. Task 2E will freeze execution
scope and persist results around background workers.

## Verification

tests/testthat/test-full-tables.R exercises full reads beyond previews, late
malformation, independent siblings, quotas/cancellation, UTF-16LE, exact lexical
values, empty tables, headerless data, descriptor indices/namespace/paths,
confirmed/suggested mappings, configuration ownership and source integrity.
tools/manual-full-tables.R registers the available real examples through the
upload service and records only technical summaries under ignored evidence/.
The exact Occurrence_Measures_Example1.zip reference archive was unavailable;
its expected 8,480/2,916 populations are not applied to other archives.
