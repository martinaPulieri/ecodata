# Manual checks: Step 2C linkage

This increment exposes documented R services. A new Shiny validation-results
button and persisted findings belong to Task 2E.

From ecoplatform-r/, using the project library and documented Windows locale:

    Rscript --vanilla tools/manual-linkage.R

Set ECODATA_EXAMPLES to data_examples if necessary. Optionally choose a new local
ECODATA_LINKAGE_ROOT outside Dropbox. Existing runtimes are refused.
The script runs a deliberately faulty synthetic declared archive through the
actual engine, then compares candidate keys on the real OBIS preparation.
It never approves real OBIS settings or semantics. Technical evidence and the
synthetic typed records are written to ignored evidence/linkage/.

## Using a registered source

    pkgload::load_all(".")
    repo <- open_repository("ABSOLUTE_LOCAL_RUNTIME")
    result <- run_linkage_validation(repo, version_id, config_id)
    result$status
    lapply(result$mappings, function(m) list(
        mapping_id=m$mapping_id, status=m$status, reason=m$reason,
        counts=if(is.null(m$summary))NULL else m$summary$counts,
        evaluated=m$evaluated_measurements, unclassified=m$unclassified_rows))
    close_repository(repo)

Use mapping_id to select one available unambiguous saved/descriptor-derived
relationship. Resolve competing mappings through the existing clarification
workflow first. Historical configurations can be evaluated while their input
version remains active; all provenance identifies the exact selected revision.

## Expected synthetic outcomes

The fixture has 7 core rows and 9 measurements:
- 4 linked to unique targets (including literal NA and an exact spaced key);
- 1 ambiguous reference with 2 core targets;
- 1 missing reference;
- 3 unresolved references, preserving 001 versus 1 and significant spaces;
- one repeated core-key group affecting 2 rows;
- one core row with a missing key;
- one unique core key with no measurement;
- 3 edge-whitespace warnings.

There must be 9 outcome records, not a row-multiplying joined table. Findings
contain original values, exact mapping context and source row locators.
Several measurements referencing one unique observation are legitimate.

## Boundary checks

- Empty core/measurement tables retain known zero populations; missing members
  retain unknown populations and explicit not_evaluated state.
- Unconfirmed parser/mapping or stale headers cannot trigger matching.
- Disable LNK-07/08: corresponding diagnostics are absent and disclosed.
  Disable a mandatory rule: the relationship is not evaluated.
- Use max_candidate_targets=1, max_findings=1 or max_output_rows=1 on the fixture.
  Expect limited, zero evaluated measurements and no partial success.
- Pass cancelled=function() TRUE: expect cancelled and no retained partial results.
- The unit tests also cancel during construction, alter source bytes before the
  final integrity check, exercise two resources and verify whole-run budgets.
- Confirm configuration revision count, configuration/source hashes and operation
  count remain unchanged. Rerunning is read-only and deterministic.

## OBIS scope comparison

    input <- read_validation_tables(repo, version_id, config_id)
    audit <- compare_linkage_key_scope(input,
        core_table_id, extension_table_id,
        core_id_position=1, extension_reference_position=1,
        core_scope_position=0, extension_scope_position=0)

Positions are zero-based and must be verified against actual headers; these
positions refer specifically to the supplied OBIS TSVs (dataset_id, id).
The diagnostic explains whether adding dataset_id changes uniqueness, target
resolution or reveals namespace conflicts. It does not adopt or approve a
relationship. Its counts remain provisional while technical settings are pending.
A compound key required in another dataset cannot yet be executed by the
single-column contracts; record that requirement and obtain an explicit extension.

Additional regression cases keep absent saved mappings visible, reject effective
ID collisions, invalidate stale readiness after source modification, and verify
zero-row and multi-target namespace diagnostics. Unicode whitespace warnings show
their code points so non-breaking space is distinguishable from ordinary space.
