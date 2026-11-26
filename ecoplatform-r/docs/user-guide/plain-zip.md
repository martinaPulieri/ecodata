# ZIP collections without meta.xml

The app now supports ordinary ZIP collections containing CSV, TSV or TXT tables.
If meta.xml is present, the descriptor reader remains authoritative. A malformed,
unsupported or ambiguous descriptor is reported; it is never bypassed by treating
the archive as a generic collection.

For an ordinary ZIP, each table is read independently. JSON, HTML and other
sidecars are listed as ignored members; they are not executed or used as
instructions. ZIP paths, duplicate names and expansion limits are checked before
reading. Nothing is extracted into the workspace.

## Operator workflow

1. Register the ZIP normally and generate a **Preview**. Each readable table
   has its own selector. The preview is explicitly provisional where needed.
2. Open **Missing information** and choose **Check missing information**.
3. For each member, inspect encoding, separator, quoting and whether the first
   row contains headers. **Use as draft** fills a proposal without saving.
   Header presence is always uncertain without a declaration and needs approval.
4. Review the exact member/settings/evidence, then **Approve and save new revision**. Each approved answer creates one append-only configuration.
   Cancel saves nothing. Another member does not inherit this approval.
5. Confirm date roles/components separately. A column named eventDate in a plain
   ZIP is a suggestion, not a descriptor declaration.
6. For linkage, explicitly choose both tables and their key columns. Filename
   Occurrence/MeasurementOrFact and shared id headers only suggest a possible
   relationship. Verify what id means and whether dataset_id is needed to scope
   it. The app does not infer a valid join from filenames or equal headers.

Approved settings apply to both previews and full reading and survive restart.
Date prerequisites can become ready independently of linkage once their own
format and role are approved. Scientific matching and date recognition are not
executed in this increment.

## Reading results

complete indicates a complete lexical scan under the currently proposed or saved
settings. While settings_pending is TRUE, loaded_rows is a candidate row count,
population_count stays unknown and PRE-01/date/linkage readiness is blocked.
Choosing a different header setting can change both the row count and schema.
Only approved settings allow a complete scan to certify its technical population.

A preview returns at most 20 complete logical records. Its byte budget is not
treated as EOF: an unfinished final row/quoted field is excluded, and incomplete
Unicode tails are handled without inventing values. If no complete record fits,
the limitation is explicit. Previews never certify whole-table populations.

One failed, oversized or cancelled member leaves readable siblings available.
An explanatory repair note does not make unreadable data pass. Changing settings
invalidates any approval that does not exactly match the new settings; saved
mappings are rechecked against the resulting actual schema.

## Manual verification

From ecoplatform-r/, with the project R library and documented Windows locale:

    Rscript --vanilla tools/manual-plain-zip.R

ECODATA_EXAMPLES selects the data_examples directory. Optionally set a new,
local ECODATA_PLAIN_ZIP_ROOT outside Dropbox for a persistent isolated runtime.
The script refuses an existing runtime.

The real OBIS archive is read with provisional settings and left unapproved.
No scientific roles, keys or uncertain settings for research data are approved
by the acceptance script. A separate synthetic fixture demonstrates four
explicit approvals (two formats, one date role and one relationship), revision
history, independent date questions and receipt persistence after reopen.

Technical evidence is written under ignored evidence/plain-zip/. Research
records and runtime databases are not included in Git.

Browser checks:
- Upload OBIS_VeniceLagoon.zip: the missing-meta.xml error should disappear.
- Generate a preview: choose either TSV table and inspect the provisional notice.
- Open Missing information: verify that each format question names its member.
- In a synthetic fixture, use a suggestion, review and cancel: no new revision.
- Approve exact settings: one new revision, sibling still pending.
- Review a relationship: both member names and exact key columns must be shown.
- Change source/revision/operator before approval: stale answers must be rejected.

This remains synchronous bounded local preparation. Large archives can keep the
UI busy; background scientific processing is a later increment.

## Quotation ambiguity

A sampled quote convention can fail later in the full table. If there is no
explicit saved member setting and quoted parsing fails, the reader may propose
literal quotes (no text enclosure) after that alternative produces a readable
table. Its evidence records the rejected interpretation. This is still a proposal:
settings_pending stays TRUE and no population or semantic mapping is approved.
An explicitly saved setting is never silently replaced by this alternative.
Review this alternative only when it is explicitly proposed with failure evidence.
