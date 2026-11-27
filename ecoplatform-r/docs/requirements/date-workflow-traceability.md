# Approved date workflow traceability

| Approved behaviour | Implementation | Evidence |
|---|---|---|
| Reading settings after registration | mod_workspace, app_ui | Existing registration tests; browser |
| Save and preview in one action, embedded below settings | mod_workspace, app_ui | test-date-workflow; browser |
| Next automatically checks in background with progress | mod_date_information, service_date_information | Real callr preparation integration; browser |
| Required information bullets, no role/evidence inputs | mod_date_information, mod_clarifications | Rendered module assertion; browser |
| Selected columns with inferred editable formats | infer_date_format, mod_date_information | DMY/MDY ambiguity, mixed/blank, override regressions |
| Dates-only validation against declarations | save_date_declarations, validation_temporal, submit_validation_run | Persisted exact-format and dates-only integration tests |
| No source conversion | Existing lexical reader and typed results | Whitespace, impossible-date, source-hash/restart checks |
| Preserve user override and selected scope | mod_date_information, explicit configuration metadata | Add-column and deselection regressions |
| Context-bound drafts and recoverable worker errors | mod_date_information | Cross-file and launch-failure regressions |

Validation and Results screens retain their existing layout. Linkage semantics,
calendar checks, automatic correction and Task 2F qualification are outside this change.
