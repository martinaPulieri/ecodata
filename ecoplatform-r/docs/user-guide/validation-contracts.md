# Inspecting validation contracts before the check engine exists

Task 2A adds documented R APIs and configuration persistence. It adds no validation
button and produces no detected findings. The demonstration supplies synthetic
classifications by hand to verify their representation and counting only.

From `ecoplatform-r/`, using the existing R dependencies:

```text
Rscript --vanilla tools/manual-validation-contracts.R
Rscript --vanilla tools/test-step1.R
Rscript --vanilla tools/check-step1.R
```

Optionally set ECODATA_R_LIBRARY to an existing package library. The demonstration
uses a new temporary local runtime. ECODATA_CONTRACTS_ROOT may select a new local
non-synchronised directory; existing paths are refused. It generates only synthetic
CSV/archive files, preserves their hashes and never touches the user's datasets.

Open `evidence/validation-contracts/manual-result.json` after a successful run:

1. In the context, inspect catalogue versions/hashes and configuration ID/hash.
2. In the sampling mapping, verify year position 0, day position 1, month position 2;
   the source headers are anno, giorno, mese. Indices are zero-based.
3. Sampling row 1 retains year `2020`, day `7`, month `03`, widths 4/1/2 and the
   split-numeric candidate. Row 2 is incomplete with missing month; row 3 is missing.
4. The sampling summary has one recognised, one incomplete and one missing row.
5. The separate analysis-date example retains `03/04/2020` and both DMY/MDY patterns.
6. The linkage declaration selects core id and extension reference at index 0,
   distinct from occurrenceID. The five hand-specified measurement outcomes count
   two linked, one ambiguous, one unresolved and one missing reference.
7. Check that the ambiguous row carries two candidate core locators but counts
   once. The two rows targeting `001` remain two legitimate measurement rows.
8. Confirm restart_preserved_context/unchanged_source_hashes are true and
   operations_created is zero. Summary and record examples are exported as one
   structured JSON document; no result records are written to new SQLite tables.

To inspect through R, load the package and use `?new_validation_spec`,
`?new_date_mapping`, `?new_date_result` and `?freeze_validation_context`.
Existing saved configurations without validation_spec remain valid and readable.

The exact reference archive Occurrence_Measures_Example1.zip was not used here.
Its documented 8,480/2,916 inventory counts and real validation results remain
unmeasured. No scientific linkage or date-pattern acceptance is claimed by this
contract demonstration. See [architecture and scope](../architecture/validation-contracts.md).
