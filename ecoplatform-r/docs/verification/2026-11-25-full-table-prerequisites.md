# Task 2B — complete reading and independent prerequisites

Implemented on 25 November 2026; the user approved commit and push of Step 2B, clarifications and ordinary ZIP support.

## Delivered scope

Two documented read-only APIs prepare exact registered/configured inputs:
read_validation_tables() and assess_validation_prerequisites().
They preserve decoded strings and logical record identities; resolve descriptor
member settings, id/coreid and eventDate positions; check actual saved mapping
schemas; and report PRE-01, LNK-01 and TMP-00 independently.
A missing or malformed extension never disables a readable core date mapping.

No matching, date-pattern classification, calendar validity, result persistence,
SQLite migration or new Shiny validation workflow is included. ready only
indicates prerequisites; scientific_rows_evaluated is zero.

## Real-input acceptance

tools/manual-full-tables.R uses the normal upload service in an isolated temporary
repository and writes technical summaries only under ignored evidence/.

| Input | Observed technical result |
|---|---|
| Venezia macrozoobenthos 2011 | Complete: 468 data rows, 235 columns; UTF-16LE/tab; two unconfirmed date candidates |
| 9dc22d78-c41c-43ac-ba09-647e5c75f0a8.csv | Complete: 42 rows, 79 columns; one unconfirmed date candidate |
| Historical landings DwC-A | Complete event.txt 57 x 10, occurrence.txt 1,083 x 8, extendedmeasurementorfact.txt 1,198 x 8 |
| Historical landings prerequisites | Event core supports eventDate preparation; Occurrence-core linkage profile is not met |
| OBIS_VeniceLagoon.zip | Unreadable as declared DwC-A: no unique supported meta.xml; population unknown |
| sonda_transizione_2010.csv | Unreadable under saved encoding; population unknown; no silent parser fallback |
| Synthetic missing extension | Linkage not_evaluated; core eventDate ready; ambiguous text unchanged |

All five original source hashes stayed unchanged. Preparation created zero
history operations. The exact Occurrence_Measures_Example1.zip reference archive
was unavailable: no 8,480/2,916 inventory or scientific findings are claimed.

## Checks and limits

Dedicated regression cases cover more than 20 rows, late malformed records,
independent resources/members, exact NA/leading-zero/multiline strings, duplicate
headers, header-only/headerless input, UTF-16LE, quotas and cancellation,
descriptor namespace/path/index failures, saved key/role/schema mismatch,
configuration ownership and integrity verification.

The reader is bounded in-memory: default 50 MiB, 1,000,000 data rows and
5,000,000 decoded fields per table. Partial/cancelled populations are unknown.
Cancellation is cooperative, not a hard interrupt of decompression or OS calls.
There is no new UI to demonstrate in this slice; the delivered results are the
R preparation services and their reproducible acceptance checks.

Final regression, package-check and independent-review results are recorded below
after execution. Raw local evidence is excluded from Git.

## Final verification and review

- Full regression suite: 557 passed assertions; zero failures, errors, warnings
  or skipped assertions. This includes 94 Step 2B assertions beyond the 463
  assertion baseline, with existing Shiny and history tests still green.
- A fresh read-only reviewer reproduced five material cases. Regression tests
  failed before correction and passed after: missing extension locations,
  independent saved/descriptor date fields, separate metadata quota,
  missing measurement population and duplicate eventDate positions.
- Namespace and saved descriptor-role tests also failed before their fixes.
- Final real-input demonstration reproduced the inventories above and confirmed
  unchanged original hashes, zero scientific rows and zero preparation operations.
- Generated R help covers both new exported APIs.
- No files were staged and no commit or push was made.
- Final built/installed R CMD check --no-manual: Status: OK (no warnings or notes).


Publication approval (25 November 2026): the user approved committing and pushing
Step 2B, clarification workflow and ZIP support without meta.xml to martinaPulieri/ecodata.
Final combined verification: 772 assertions, zero failures/errors/warnings/skips; installed-package Status: OK.
