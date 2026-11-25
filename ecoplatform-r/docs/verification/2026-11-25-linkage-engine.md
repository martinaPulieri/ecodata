# Step 2C — exact linkage engine and OBIS key-scope comparison

Implemented and verified on 25 November 2026. The user explicitly approved
committing and pushing the code, tests, updated plan and documentation. Base commit: cfbbc96771bb0e24a86c1fa527a0052b6325e9ff.

## Delivered scope

run_linkage_validation() executes LNK-02--06 with enabled LNK-07/08 diagnostics.
It uses exact declared/approved relationships, preserves all decoded identifiers,
emits one outcome per eligible measurement and returns typed findings/checks,
scoped frozen execution contexts, reconciled summaries and multiplicity counts.
There is no row-multiplying join, source correction or automatic key adoption.

compare_linkage_key_scope() compares a supplied ID with its namespace-qualified
pair. It is a read-only candidate diagnostic, not an approved mapping. Empty
support, missing components, collisions and namespace conflicts are explicit.

SQLite remains v2. Configurations, originals and operation history are unchanged
during evaluation. No results persistence or new Shiny results interface is
included (Task 2E); date recognition remains Task 2D.

## Final executed verification

| Check | Observed result |
|---|---|
| Full regression suite | 928 passed assertions; 0 failures, errors, warnings or skips |
| New Step 2C tests | 156 assertions beyond the published baseline of 772 |
| Built/installed R CMD check --no-manual | Status: OK; no warnings or notes |
| Exact identity | Case, leading zeros, literal NA, Unicode whitespace and raw spaced identifiers retained |
| Technical prerequisites | Unconfirmed/absent/stale mappings and disabled mandatory rules never execute as eligible |
| Scientific coverage | Row outcomes and summaries reconcile; duplicate groups and affected rows remain separate |
| Output bounds | Whole-run row/candidate/finding budgets limit aggregate output; cancellation drops partial records |
| Resource isolation | Healthy sibling relationships/date prerequisites survive another resource's failure |
| Integrity race | Final byte changes discard affected scientific output, readiness and population claims |
| Read-only provenance | Source/config hashes unchanged; no added configuration or operation during validation |
| Restart | Existing snapshots and configuration hashes preserved after repository reopen |

The final suite exercises existing registration, Shiny clarification, ordinary
ZIP, SQLite history and removal behaviour as well as the new engine.

## Synthetic engine demonstration

Seven core rows and nine measurement rows deliberately include multiple fault types.

| Outcome or diagnostic | Expected and observed |
|---|---:|
| Linked to one exact target | 4 |
| Ambiguous reference | 1 measurement, with 2 candidate core rows |
| Missing reference | 1 |
| Unresolved reference | 3 |
| Not evaluated | 0 |
| Outcome records | 9, matching the 9 input measurements |
| Missing core key | 1 row |
| Repeated core keys | 1 group affecting 2 rows |
| Unique core keys without a measurement | 1 |
| Significant edge-whitespace warnings | 3 |

Multiple measurements for one unique core key are legitimate. The repeated core
key group is a declared-relationship uniqueness issue, not a biological duplicate
assessment. completed means the engine finished; these findings remain errors/
warnings and are not a dataset pass.

## OBIS: is dataset_id + id needed?

The supplied OBIS_VeniceLagoon.zip was read again with the canonical full-table
reader. Scope positions were verified against unique actual headers:
dataset_id at 0, id at 1, in both TSV members.

| Candidate comparison | id | dataset_id + id |
|---|---:|---:|
| Core candidate rows | 5,831 | 5,831 |
| Unique nonmissing core keys | 5,831 | 5,831 |
| Repeated core-key groups | 0 | 0 |
| Measurement references with one target | 2,762 | 2,762 |
| Ambiguous references | 0 | 0 |
| Unresolved references | 0 | 0 |

There are 29 core dataset_id values, no missing ID/scope components and zero
namespace disagreements. The composite candidate therefore does not improve
uniqueness or change target resolution in this observed snapshot.
Resolution: single_key_sufficient_for_this_snapshot.

These are provisional key-comparison observations: member settings and semantic
relationships for the real archive remain unapproved, and the actual validation
run remains blocked for those missing prerequisites. No real answer is adopted
and the archive keeps configuration revision 1. The result does not establish
global ID uniqueness for other OBIS downloads or approve a relationship merely
because its values match.

Synthetic cross-dataset collisions demonstrate that the diagnostic instead reports
compound_key_required_for_uniqueness when a pair is needed. Current execution
contracts remain single-column; a future such dataset requires an explicit
compound execution-contract extension. This archive did not require it.

The separate Occurrence_Measures_Example1.zip reference archive was unavailable;
its 8,480/2,916 inventory is not applied to this OBIS dataset.

## Fresh review and fixes

One fresh read-only reviewer reproduced five material cases. Tests failed before
the corrective pass and passed afterward:
1. Saved mappings to absent members remain visible as not_evaluated scopes;
   an available descriptor sibling still executes.
2. Final integrity failures invalidate affected linkage/date readiness and source
   populations, preserving healthy sibling resources.
3. Empty tuple inputs produce zero keys/references, not a phantom match.
4. A known ID with several targets but no target in the requested namespace is a
   namespace conflict, not an automatically usable composite proposal.
5. Blocked row materialisation and linkage-summary reconciliation poll cancellation
   and discard partial records.

Additional tests guard effective descriptor/saved ID collisions and visible
Unicode whitespace code points. There was no second review; the final full suite
and installed-package check ran after all fixes.

## Reproduction and local evidence

Run tools/manual-linkage.R with the project R library and documented Windows
locale. The isolated persistent runtime is:
C:/Users/tina_/AppData/Local/ecodata/linkage-review-20261125-final.

Ignored local evidence:
- evidence/linkage-regression-final.txt
- evidence/linkage-package-final/package-check.txt
- evidence/linkage-manual-final.txt
- evidence/linkage/synthetic-result.json
- evidence/linkage/obis-scope-diagnostic.json
- evidence/linkage/manual-result.json

See docs/user-guide/linkage-engine.md for manual commands and expected results;
docs/architecture/linkage-engine.md explains contracts, limits and counting.
No new browser UI was added or claimed in this slice. Processing remains bounded
and synchronous; background scientific orchestration/results storage are future work.


Publication approval (25 November 2026): the user approved Step 2C code, tests,
updated plan and documentation for commit/push to martinaPulieri/ecodata.
Verified suite: 928 assertions with zero failures/errors/warnings/skips; installed-package Status: OK.

Publication recheck: the installed-package check completed with Status: OK.
One initial source-directory run encountered a temporary access-denied error
reading the unchanged 002_workspace_lifecycle.sql in an existing Shiny-removal
test. The file was verified byte-identical to HEAD and readable; the subsequent
serial source run passed all 928 assertions with zero warnings/errors/failures.
No migration SQL or runtime behaviour was changed in response to that access error.
Local evidence: evidence/publication-2c-regression-serial.txt and
evidence/publication-2c-package/package-check.txt.
