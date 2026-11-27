# Standalone delimited TXT reading — 27 November 2026

## Diagnosis and change

The supplied Groundwater_Copepod_Trait_error.txt is a UTF-8, comma-delimited
table with 314 rows and 34 columns. Standalone format gates accepted CSV/TSV
only, although ZIP members already supported TXT. The date edits did not cause
the encoding/delimiter warning.

A shared private predicate now enables standalone CSV/TSV/TXT consistently in
detection, bounded preview, full validation reading, clarification and the
Shiny Detect format control. Detection still requires encoding and separator
evidence; prose TXT stays unresolved and PDF stays unsupported. Original text,
quoted commas and whitespace are preserved. Existing TXT registrations require
Detect format to save fresh detection evidence in a new revision.

## Supplied-file acceptance

The real upload, preview, full-table preparation and supervised date worker
completed with 313 recognised lexical patterns and one unrecognised value.
There were no missing, ambiguous, incomplete or unevaluated date records.
The source SHA-256 was unchanged, and reopening the repository returned the
identical saved result. The acceptance helper refuses an existing test runtime.

The first value, `2025-19-02`, matches YYYY-MM-DD lexically. Month 19 is
impossible, but calendar validity is outside the implemented check. The second
value, `2025-02-19 `, contains a trailing space and fails the exact pattern.
These results must not be described as 313 calendar-valid dates. The unsupported
value also prevents an all-values format suggestion; the expected format can
be declared explicitly. No trimming, correction or calendar checks were added.

## Verification

Failing-first tests reproduced the unsupported TXT gates. Focused detection,
TXT and Shiny workspace tests passed, including UTF-16/tab input, quoted commas,
redetection, original values, full reading, prose TXT and unsupported PDF.
Independent review found no actionable issues.

The live Shiny app confirmed the old warning, Detect format producing UTF-8/comma
in revision 2, and a ready preview in revision 3. Next displayed missing-information
progress. Selecting eventDate showed the mixed/unsupported explanation; an
explicit YYYY-MM-DD declaration produced revision 4 and submitted date validation
with its progress indicator. All earlier revisions were retained.

The full suite passed 1,270 assertions with zero failures, errors, warnings or
skips. Installed-package build/check finished Status: OK, with no warnings or
notes. The browser displayed the completed revision 4 result: 313 recognised,
one unrecognised, and coverage of 314/314. The original text in row 2 retained
its trailing space. No browser console errors were recorded. Results were shown
before publication. The user approved committing and pushing the implementation,
tests and updated documentation on 27 November 2026.

Local ignored evidence under ecoplatform-r/evidence/: delimited-txt-red.txt,
delimited-txt-focused.txt, delimited-txt-suite.txt, delimited-txt-package/,
delimited-txt-manual.txt, delimited-txt/manual-result.json and
delimited-txt/reading-detected.jpg, delimited-txt/date-results.jpg and
delimited-txt/final-live-result.json. Research data are not added to source control.

Commands: tools/test-step1.R, tools/check-step1.R and
tools/manual-delimited-txt.R with ECODATA_DATE_INPUT naming the supplied file.
Environment: Windows, R 4.4.3, existing ECODATA_R_LIBRARY, LANG=en_US.UTF-8,
LC_ALL=English_United States.utf8.
