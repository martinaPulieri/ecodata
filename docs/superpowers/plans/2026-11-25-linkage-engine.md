# Step 2C: exact linkage engine and identifier-scope audit

> Use superpowers:executing-plans. The user approved Step 2C implementation/tests/
> documentation and the OBIS composite-key investigation. Do not stage, commit or
> push before separate approval.

Goal: execute LNK-02–06 with optional LNK-07/08 over declared or explicitly approved
single-column archive relationships. Return typed, reconciled outcomes and
findings without joins that multiply source rows or any source modification.

Architecture: read-only run_linkage_validation service -> existing full reader/
independent prerequisites -> exact-key index -> existing typed result contracts.
Execution context retains original config/hash/resource hashes and explicit
effective mappings (including descriptor-derived declarations) without saving
them. SQLite stays v2; scientific result persistence/UI belongs to 2E.
Tech stack: existing R package, Shiny configuration workflow, DBI/SQLite history.

Spec: approved main plan Task 2C and workspace ValidationRules.md LNK-01–08.
User explicitly authorised checking whether OBIS needs dataset_id + id.
Independent initial inventory: 5,831 unique core IDs across29datasets; all2,762
references unique under both id and pair; zero dataset mismatch. Therefore no
composite mapping/result contract extension is needed for this snapshot.
A read-only scope audit reports collisions/conflicts/insufficient evidence on
other data; it does not silently approve or change a key. Existing single-column
contract stays compatible; future compound-key execution needs explicit scope.

Constraints:
- Exact decoded text, case, whitespace, leading zeros and literal NA preserved.
- One outcome per known measurement row; unknown populations remain unknown.
- Missing/duplicate core keys, legitimate repeated measurements, unresolved/
  ambiguous references, unmeasured core rows and whitespace evidence separate.
- Missing/disabled mandatory rules block execution; optional diagnostics disclose
  disabled status. Cancellation/output/finding/candidate quotas never claim a pass.
- Independent mappings/resources and date prerequisites survive sibling failures.
- No new validation button, results DB tables, scientific date rules or data joins.

- [x] Task 1: failing tests first for actual exact linkage fixtures, findings,
  coverage/multiplicity, empty tables, optional/disabled rules and typed summaries.
  Implement R/validation_identifiers.R and R/service_linkage.R.
- [x] Task 2: test missing/unconfirmed/schema-mismatched mappings, quotas,
  cancellation, removal, source/context isolation, descriptor effective context
  and generic archive approval compatibility. Implement bounded technical outcomes.
- [x] Task 3: read-only compare_linkage_key_scope audit with collision-free tuple
  encoding and tests for cross-dataset collisions, namespace conflicts, partial
  scope/missing values and compound pairs still nonunique. No automatic adoption.
- [x] Task 4: documented manual synthetic + real OBIS comparison, generated R help,
  roadmap update, full regression/package check and one fresh read-only reviewer.
  Show results and await user approval. No staging/commit/push.

Review focus: result/context reconstruction, candidate explosion, null/zero versus
unknown populations, whitespace/case/Unicode exactness, default catalog provenance,
disabled rules and independent multi-resource technical failures.

Final verification: 928 assertions; installed-package Status: OK. Synthetic9measurements ->4linked,1ambiguous,1missing,3unresolved. Canonical OBIS audit:5831uniqueIDs across29datasets,2762unique targets under id and pair,0namespace conflicts. No real approvals adopted; no compound execution extension required for this snapshot. Five reviewer findings reproduced and corrected, final full suite/check/manual after fixes. No staging/commit/push.

Publication approval (25 November 2026): the user approved Step 2C code, tests,
updated plan and documentation for commit/push to martinaPulieri/ecodata.
Verified suite: 928 assertions with zero failures/errors/warnings/skips; installed-package Status: OK.
