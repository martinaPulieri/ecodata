# Step 2C: exact linkage engine

run_linkage_validation() runs relational identifier checks on an exact active
registered version/configuration. It reads complete tables and uses Step 2B
prerequisites. It performs no join, source correction, configuration save,
operation-history insert or scientific-result persistence. SQLite stays v2.
Date recognition and the Shiny results workflow remain Tasks 2D/2E.

## Eligibility and frozen context

A supported descriptor may supply its exact id/coreid mapping, independently of
occurrenceID. A plain ZIP requires the existing explicitly approved member formats
and user-declared table/key relationship. Unconfirmed, stale, absent or unreadable
members do not become eligible through this engine. Multiple competing mappings
must first be resolved through the clarification workflow.

Each relationship receives its own effective frozen context: original config ID/
hash, workspace revision, scoped immutable resource ID/hash/size, complete rule/
pattern snapshots and exact mapping provenance. Descriptor-derived declarations
are included in memory without silently appending a configuration revision.
Saved configurations remain unchanged. A bad mapping/date schema elsewhere cannot
invalidate a usable relationship. rules_source distinguishes configuration
snapshots from explicitly captured application defaults for legacy/no-spec input.
Only linkage mappings enter these scoped contexts; original date prerequisites
are returned independently. They are execution contexts, not replacement configs.

## Exact matching and coverage

The engine indexes nonmissing decoded keys by exact value. Group numbers are
internal factor labels, so source separators/whitespace cannot collide as group
names. Missing means empty or whitespace only under the existing Unicode policy;
literal NA remains an identifier. No trimming, numeric conversion, case folding,
Unicode normalization or guessed occurrenceID substitution occurs.

Every known eligible measurement row receives exactly one typed outcome:
linked, ambiguous, missing_reference, unresolved_reference or not_evaluated.
Candidate core row locators are attached without multiplying measurement rows.
Existing constructors and summary reconstruction check context/identity/hash and
one outcome per logical source row.

Rules:
- LNK-02: one missing-core-key finding per row.
- LNK-03: one repeated nonmissing core-key finding per group, all member locators.
- LNK-04: one missing-reference finding per measurement.
- LNK-05: one unresolved-reference finding per nonmissing measurement.
- LNK-06: one ambiguity finding per measurement, candidates in its row outcome.
- LNK-07: counts per unique nonmissing core key, measured/unmeasured unique rows,
  missing-key rows and repeated-key groups/affected rows kept separate.
- LNK-08: edge-whitespace warnings retaining original text and visible evidence;
  exact matching still uses that whitespace.

completed means execution completed, never that data passed. Check coverage
counts the scanned source rows for the rule predicate; reference-missing and
other ineligible-to-match rows are still scanned and classified explicitly.
All mandatory LNK-01--06 must be enabled to claim complete linkage execution.
Disabled optional rules are listed, with their diagnostic output absent.
No biological duplicate, calendar, geography or taxonomy check is inferred.

## Limits, interruption and resource isolation

Default whole-run limits: 25,000 combined core/extension source rows represented,
250,000 candidate locators and 100,000 findings. Limits are shared in deterministic
relationship order. Core rows are included because findings/multiplicity can
represent them individually. Input reading retains Step 2B quotas.
Before publishing scientific output, candidate/finding quotas are checked.
A limit never truncates a successful-looking result. Known readable references
can instead receive not_evaluated records within the remaining output budget;
unknown headers/populations or exhausted output capacity produce no fabricated
rows or zero population. unclassified_rows distinguishes absent row records from
an unknown population. Only completed mappings count evaluated_measurements.

Cancellation is cooperative and discards partial scientific records. The public
service checks source integrity again after evaluation and invalidates affected
resources only; lifecycle revision is rechecked before return. It does not lock
files against an external malicious writer. Other readable mappings/date
prerequisites remain independent; quotas/cancellation can explicitly limit a run.

## Namespace/composite-key diagnostic

compare_linkage_key_scope() is a pure diagnostic on a fresh preparation. It compares
the supplied identifier with a namespace+identifier tuple, without approving or
adopting either mapping. Every tuple component is framed by its UTF-8 byte length,
so delimiters inside values cannot collide. Blank IDs/scopes are missing
components, never invented namespace values.

It reports single-key sufficiency for this snapshot, compound required for
uniqueness, compound still insufficient, namespace conflict or insufficient
information. Pending member settings remain settings_provisional=TRUE and
mapping_adopted is always FALSE. This is candidate evidence, not a declared
relationship or stored LNK result.

The supplied OBIS inventory has unique id values across its 29 datasets, and the
single-ID and dataset_id+id target counts agree with no namespace disagreement.
A compound execution contract is therefore not required for this observed
snapshot. Existing single-column contracts remain compatible. Synthetic
cross-namespace collisions prove the diagnostic detects when a pair would be
needed. The engine does not execute a compound relationship; such future data
requires explicit contract/workflow extension, rather than silently concatenating
columns or adopting a proposed namespace.

## Review hardening

Every saved relationship is reconciled with the prerequisite inventory. A saved
mapping with a missing member remains an explicit not_evaluated scope alongside
any usable descriptor-derived sibling. An effective descriptor ID conflicting
with a different saved mapping is blocked rather than silently reusing its ID.

If the final integrity check fails, affected linkage and date prerequisites lose
ready status and their populations/eligibility become unknown/zero. Scientific
outputs and source populations for that resource are discarded; healthy siblings
retain their own results. Frozen context hashes still identify the expected
original resource, not an assertion that damaged bytes are verified.

Blocked/not_evaluated row construction also polls cancellation. Linkage summary
reconstruction accepts an optional cooperative cancelled function and polls it
periodically; its default preserves the existing API behaviour. A late whole-run
cancellation discards partial records before return.

Empty namespace/key vectors yield zero tuples. No source rows means insufficient
evidence for deciding key scope, never a phantom match. Namespace conflict counts
include a known ID with multiple targets when none belongs to the supplied known
namespace; missing namespace information remains explicitly insufficient.
Whitespace diagnostics include leading/trailing Unicode code points (for example
U+00A0), retaining exact raw values and equality.
