# Missing-information questions and approved answers

Open **Informazioni mancanti** for an active input and its latest configuration.
Choose **Verifica informazioni mancanti**. The application reads complete tables
within the Step 2B quotas, then shows questions for the selected file. Each
question explains why information is needed and which prerequisites depend on it.

Supported answers:
- Parser: encoding, separator, decimal declaration and quoting. An ambiguous
  technical format remains pending until the actual settings receive approval.
- Dates: a role and either one field or separate day/month/year columns, in any
  order. A documented date order is optional and needs evidence; otherwise
  ambiguity is retained. Several independent date fields can be clarified.
- Linkage: core/reference positions when the supported archive relationship is
  readable and a key declaration is genuinely absent. A known key is not replaced
  by occurrenceID. Conflicting, invalid or out-of-range declarations require a
  corrected source.
- Source repair: explain missing files, unavailable descriptors, unsupported
  relationships or failed source integrity. Use **Aggiungi dati** to register a
  corrected source. An approved note records the answer but leaves checks pending.

**Usa come bozza (non salva)** copies a suggestion into the controls. It does not
approve a role or save a configuration. Fill in the role/columns and evidence,
then choose **Rivedi la risposta**. The modal shows the exact values and any
mapping replacements. **Annulla** writes nothing. Only **Approva e salva nuova
revisione** accepts the displayed draft.

Where old mappings compete for the same relationship or refer to stale headers,
the modal lists the mappings to replace. Approval retires those mappings from
the new revision; their complete old definitions remain in historical revisions.
Independent valid mappings are preserved. Retired date fields may require new
answers against the actual headers.

The answer history shows values, operator, approval time and evidence for the
selected file/revision. User labels describe the local operator; they are not
authenticated identities. The immutable source, preceding configurations and
original detection evidence remain available.

Switching source/configuration invalidates the draft. Changing operator,
removing/restoring an input, a concurrent revision, changed bytes or an old
approval event cannot apply a stale answer. Reload the latest context and
review again. A repeated approval does not create another revision.

A prerequisite marked ready is only eligible for a later scientific check.
Approval does not prove that an encoding guess is correct or a date is valid.
A wrong supplied parser can remain unreadable. Independent checks continue;
matching/date recognition and background validation operations remain future work.

## Reproducible manual verification

From ecoplatform-r/, with the project R library and the documented Windows locale:

    Rscript --vanilla tools/manual-clarifications.R

ECODATA_EXAMPLES can identify the data_examples directory. An optional new
ECODATA_CLARIFICATIONS_ROOT chooses a persistent local runtime outside Dropbox.
The script refuses an existing runtime and writes technical evidence to
evidence/clarifications/manual-result.json (ignored by Git).

The real Venezia file is read and its two date requests remain unanswered.
No semantic answer for research data is invented or approved by the script.
An explicitly defined synthetic fixture demonstrates review without writes,
rejection without approval, one approved revision, remaining independent date
requests, receipt persistence after reopen and unchanged original hashes.

Browser checks:
1. Launch tools/launch-shiny.R against the isolated acceptance runtime.
2. Select Venezia, open Informazioni mancanti, request information and use a
   suggestion. Verify that configuration revision stays 1 and the role is blank.
3. Use the synthetic fixture to fill a known role and review it. Inspect the
   exact columns/evidence; cancel and verify no new revision.
4. Review again and approve. Verify one new revision and the saved answer in
   history. Select the old revision to inspect the earlier state.
5. Reload missing information. The other unconfirmed field still has its own
   question. Dates do not become scientifically valid through approval.
6. Repeat an old approval or change context/operator; saving must be rejected.
