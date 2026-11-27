# Configure reading, preview and declare date formats

1. Register a CSV, TSV or ZIP. Registration opens **Data and configuration** with
   the detected reading settings. Review encoding, delimiter, decimal mark and
   quoting. ZIP descriptors remain authoritative; plain ZIP table settings can be
   clarified separately.
2. Select **Save and generate preview**. This creates one configuration revision
   and a recorded preview using that exact revision. The preview appears directly
   below **Reading configuration**, with original text preserved. Historical
   revisions offer **Preview saved revision** without saving changes.
3. Review the preview and select **Next** at the bottom right. The app opens
   **Missing information** and checks the tables in a separate process. An
   indeterminate progress bar remains visible while the check runs; it does not
   claim a percentage when the total work is unknown. Switching context discards
   the old preparation. Errors are displayed with a return-to-configuration action.
4. Under the **Required information** bullets, select the date column(s) for each
   relevant table. **Date format** is suggested from the values and can be changed.
   For separate columns choose **Separate day, month and year** and assign each
   component. Multiple independent date columns can be selected.
5. Choose a format explicitly when values are ambiguous, mixed, unsupported or
   entirely blank. For example, `15/03/2020` supports a DMY suggestion, whereas
   `03/04/2020` by itself cannot distinguish DMY from MDY. Mixed formats do not
   silently become one declaration. Select the expected format to check against.
6. Select **Run validation** at the bottom right. It saves the selected fields and
   formats in a new immutable revision and queues **dates only** using that exact
   revision. The existing Validation and Results screens show progress and saved
   classifications; those screens have not been redesigned in this change.

There is no Date role or Reason/evidence input. Technical provenance records the
explicit selection, operator and revision automatically; the internal neutral
`date_field` label assigns no scientific meaning. Non-date reading/relationship
questions remain under **Other reading or relationship information**.

Supported declarations come from the versioned date catalogue: YYYY-MM-DD,
DD/MM/YYYY, MM/DD/YYYY, DD-MM-YYYY, MM-DD-YYYY, YYYY, YYYY-MM, the supported UTC
timestamp with a literal Z, timestamp without a timezone suffix
(`YYYY-MM-DDTHH:mm:ss`), the supported year-first interval and separate numeric components.
Unlisted formats are not silently accepted or converted.

The guided flow now uses catalogue 1.2. For example, `2009-06-29T00:00:00`
requires **YYYY-MM-DDTHH:mm:ss**. **YYYY-MM-DD** does not include a time, and
**YYYY-MM-DDTHH:mm:ssZ** requires an actual trailing Z in every matching value.
An absent timezone stays unspecified; the app does not infer UTC or append Z.
The detected format is shown explicitly beside the selector. If a different
format was previously saved, it remains selected until you choose the new format
and run again; historical results are retained.

Two-digit-year slash formats are separate options: **DD/MM/YY** and **MM/DD/YY**.
For example, `17/05/11` matches DD/MM/YY, whereas DD/MM/YYYY requires four year
digits such as `17/05/2011`. A column containing `17/05/11` provides evidence for
day-first order; `12/10/11` alone remains ambiguous until a format is selected.
The year stays `11`: no century is inferred and the original text is not expanded.
Mixed two/four-digit year widths remain a format mismatch for a single declaration.

The supplied Venezia 2011 `.csv` is UTF-16LE and tab-separated; use the automatically
detected encoding/separator. File extensions do not determine reading settings.

For a declared DD/MM/YYYY field, `15/03/2020` matches; `2020-03-15` is classified
unrecognised for that declaration even though it is another known date format.
Blank/incomplete values retain their separate classifications. Whitespace and
fixed-width differences remain visible and can produce a mismatch.

Inference can use plausible month positions to distinguish DMY/MDY. Validation
checks lexical shape only: `30/02/2020` still matches DD/MM/YYYY. It does not
certify calendar validity or modify, trim or replace any original value.

Older mappings without a declared format keep their original multi-pattern
recognition behaviour. Existing saved assessments retain their exact definitions.
Declaring a format requires a new run; historical results are not rewritten.
