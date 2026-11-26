# Task 2D requirements and acceptance boundary

This increment implements the lexical date subset of RF10/RF14 and structured
in-memory results supporting future RF16. It does not complete these requirements.

| Rule | Implementation | Executed acceptance cases |
|---|---|---|
| TMP-00 | Existing independent prerequisites; service_dates.R; per-mapping frozen contexts | User confirmation, descriptor eventDate provenance, suggestions, stale schemas, missing members, multiple roles, exact source/version/config/lifecycle binding |
| TMP-01 | validation_temporal.R; existing blank_contract_value() | Empty and Unicode whitespace values; literal NA retained as nonmissing; exact original strings |
| TMP-02 | Pattern matcher; date-patterns-1.0.json; historical 0.1 support | Mixed numeric dates, both DMY/MDY candidates, documented order, enabled patterns, partial dates, timestamp, interval endpoints, impossible calendar values retained as lexical matches |
| TMP-03 | Named component extraction and split matcher | Reordered anno/giorno/mese columns, leading zeros, observed widths, one missing component, all missing, excessive widths, nonnumeric components |
| TMP-08 | Typed new_date_result() and summarise_date_results(); per-pattern candidate counts | One row per mapping, all six status counts, ambiguity separate from pattern membership, empty population, independent roles, restart-identical results |
| Execution safety | Read-only service, preparation reader, integrity/lifecycle checks | Output budgets across mappings, cancellation during construction/summary, damaged resource isolation, no new configurations/operations, source preservation |

Tests: `tests/testthat/test-date-engine.R`, `test-date-review.R` and
`test-date-coverage.R`. Synthetic operator demonstration:
`tools/manual-dates.R`. Actual commands and final results are recorded in
`docs/verification/2026-11-26-lexical-dates.md`.

Shiny Run/progress/results controls, SQLite result storage and integrated browser
acceptance remain Tasks 2E/2F. Calendar validity, interval ordering, timezone
interpretation and broader RF10 checks remain later scientific validation work.
