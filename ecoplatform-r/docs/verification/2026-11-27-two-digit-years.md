# Venezia two-digit-year recognition — 27 November 2026

## Diagnosis

The supplied `VE_12_ACTRMO0038_Dati macrozoobenthos Venezia 2011.csv` has 468
DATA PRELIEVO values and 16 distinct date strings, including `17/05/11`,
`12/10/11` and `19/05/11`. The actual shape is DD/MM/YY,
not DD/MM/YYYY. Catalogue 1.1 and earlier explicitly excluded two-digit years,
so both inference and a four-digit-year declaration could not match this input.
The file is UTF-16LE (FF FE BOM) and tab-separated despite its CSV extension.
The app's automatic reading detection correctly reports both settings.

## Change

New immutable catalogue 1.2 adds dmy-slash-yy (DD/MM/YY) and mdy-slash-yy
(MM/DD/YY). Earlier definitions and saved results remain unchanged. The guided
flow uses 1.2. The existing generic-width engine 1.1 handles these definitions
without a matcher change; catalogue and engine versions are recorded separately.

Inference uses month-position evidence for order. 17/05/11 supports DMY, while
12/10/11 alone retains both candidates. Exact declared widths remain enforced;
17/05/2011 does not match DD/MM/YY. Original values, whitespace and year text
remain untouched. No century, calendar validity or conversion is inferred. The
date controls explicitly disclose that two-digit years retain an unspecified century.

Inference checks each distinct nonblank text once. Repeated abundance counts in
wide tables cannot change an all-values pattern decision, so duplicates add no
evidence. This refactor affects suggestions only; scientific validation retains
every row and its original value.

## Verification

Failing-first tests reproduced absent inference/candidates and rejected declarations.
Focused workflow, timestamp and new two-digit-year tests passed. The new coverage
checks order ambiguity, mixed year widths, whitespace, original text and observed
widths, disabled old catalogue support and source integrity. Focused independent
review found no important correctness/backward-compatibility issue.

`tools/manual-two-digit-years.R` registers a copy through the real upload service,
verifies detected UTF-16LE/tab settings and evaluates the known date column with a
supervised worker. It checks source SHA-256 and saved payload equality after reopen.
An initial script incorrectly assumed UTF-8 and could not resolve the header;
the corrected script uses the same automatic detector as Shiny. The unsuccessful
test runtime is preserved and is not treated as successful evidence.

The final supplied-file acceptance recognised **468/468**, with zero ambiguous,
unrecognised, missing, incomplete or unevaluated records. The source hash was
unchanged and the saved payload was identical after reopen. Complete acceptance,
including automatic detection, preparation, a real worker and restart checks,
took 126.4 seconds on this machine while other checks ran. This is an observation,
not production workload qualification. The helper permits a 600-second worker wait;
an earlier run exceeded its old 120-second wait and is not passing evidence.

After the inference refactor the final full suite passed **1,250 assertions**, zero
failures, errors, warnings or skips; installed-package build/check finished
**Status: OK**, with no warnings or notes. The browser confirmed
automatic UTF-16LE/tab reading, an explicit detected DD/MM/YY next to the older
saved four-digit choice, and the no-century-inference explanation. The corrected
declaration was saved in revision 7; its completed dates-only run recognised all
468 values, with zero in every other date classification. The browser displayed
the completed summary and coverage of 468/468. A separate read-back confirmed the
saved catalogue 1.2 and unchanged registered original. Evidence is retained in
two-digit-years/final-live-result.json and inferred-ddmmyy.jpg.
Results were shown before publication. The user approved committing and pushing
the implementation, tests and updated documentation on 27 November 2026.

Local ignored evidence: two-digit-years-red.txt, two-digit-years-focused.txt,
two-digit-years-suite.txt, two-digit-years-final-suite.txt,
two-digit-years-final-package/package-check.txt, two-digit-years-manual-final.txt
and two-digit-years/manual-result.json,
under ecoplatform-r/evidence/. No research data are included in source control.

Environment: Windows, R 4.4.3, existing ECODATA_R_LIBRARY, LANG=en_US.UTF-8,
LC_ALL=English_United States.utf8. Commands: tools/test-step1.R, tools/check-step1.R,
tools/manual-two-digit-years.R with ECODATA_DATE_INPUT explicitly naming the source.
New acceptance runtimes are required; existing ones are refused.
