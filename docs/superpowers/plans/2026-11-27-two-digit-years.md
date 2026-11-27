# Two-digit date-year recognition

User reported unrecognised dates in the supplied Venezia 2011 CSV. Inspection
finds a tab-separated file with 468 DATA PRELIEVO values, all DD/MM/YY (for example,
17/05/11 or 12/10/11), not DD/MM/YYYY. Existing catalogue versions exclude two-digit years.

- [x] Reproduce failed inference/declaration with synthetic tests, including
  ambiguous DMY/MDY, exact year width and no century expansion.
- [x] Add immutable catalogue 1.2 with DD/MM/YY and MM/DD/YY; retain earlier
  definitions. Use it in guided inference/declarations; disclose unresolved century.
- [x] Test the original file via a registered copy, run the full suite and package
  check, verify Shiny, and update docs. Show results before committing.

Ruling: the existing generic-width lexical engine supports the new catalogue
without parsing, conversion or a century pivot. Its version remains 1.1;
catalogue 1.2 records the new definitions. No source values are changed.

Ruling: deduplicate text only inside format inference. Multiplicity cannot change
an all-values pattern decision, but repeated species counts in wide tables caused
minutes of redundant regex work. Full scientific validation still emits every row.
Initial full-file acceptance using an incorrect UTF-8 assumption was corrected to
the real upload detector (UTF-16LE/tab). Final tests follow the inference refactor.

Final automated evidence: 1,250 assertions passed, zero failures/errors/warnings/
skips; installed-package build/check Status OK, no warnings or notes. Real-file
acceptance recognised all 468 values, source bytes unchanged and results retained
across repository restart. Browser inferred DD/MM/YY and its no-century note;
the actual saved revision 7 run completed with all 468 dates recognised and zero
other classifications. Documentation and evidence are complete. After reviewing
the results, the user approved committing and pushing the implementation, tests
and updated documentation on 27 November 2026.
