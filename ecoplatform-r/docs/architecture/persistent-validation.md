# Task 2E: persistent validation and Shiny execution

Shiny submits an immutable operation/request and starts a supervised `callr`
process. Only serialisable runtime paths, operation IDs, package paths and worker
tokens cross the process boundary. Every worker opens/closes its own connection.
Long reading and rule evaluation run outside Shiny and SQLite write transactions.
Row JSON and insert batches are prepared before the final writer reservation.

## SQLite v3

The registered migration upgrades v1/v2 atomically to v3. Existing databases get
a verified committed SQLite snapshot before SQL changes; backup failure aborts
the upgrade. A failed statement rolls back schema changes and user_version.
Stop older app processes before upgrading their runtime: older applications do
not support v3. Do not copy a live SQLite file as an informal backup.

| Table | Role and key |
|---|---|
| validation_requests | One immutable request per operation; exact options and frozen source/configuration/code hashes |
| validation_claims | One worker token, PID and process birth time per operation |
| validation_cancellations | Idempotent cancellation receipt per operation |
| validation_progress | Append-only, sequenced family progress |
| validation_results | Final structured payload and digest per operation |
| validation_mappings | Per-family/mapping coverage, summaries and frozen context |
| validation_rows | Source row classifications; operation/family/mapping/row composite key |
| validation_checks | Typed applicability, execution and coverage records |
| validation_findings | Typed rule/severity findings |
| validation_finding_targets | Exact finding-to-source-row/value links; group findings retain multiple targets |

Foreign keys preserve operation/configuration/mapping identity. UPDATE/DELETE
triggers protect all v3 records. Scientific rows, findings, targets, coverage,
payload and the terminal operation event commit together. Failed inserts leave
no partial results. The same structured payload supports future review/downloads.

## Submission, execution and recovery

`submit_validation_run()` reuses operation idempotency/lifecycle guards inside
the same transaction as its frozen request. Identical request keys remain history
lookups after removal; changed options with the same key fail. Configuration IDs
never float to latest. Frozen state includes package-code bytes, original resource
digests, configuration, rule/pattern snapshots where saved, and lifecycle revision.
Submission validates saved manifests/acquisition state but does not hash original
source bytes or parse complete tables. Workers perform the actual byte checks.
Generic validation submissions route through the same frozen-request service.
Pre-v3 intent records retain their history and can be explicitly cancelled;
they are never represented as assessments with invented frozen provenance.

`start_validation_worker()` returns after launch. Only one worker can claim the
queued operation. `execute_validation_run()` runs existing guarded linkage/date
services independently, recording family progress. A technical failure in one
family leaves the other available. Existing engine quotas remain explicit; the
default output budget is 25,000 rows per family. This is not workload qualification.
Final source/code integrity is checked after all batch preparation, outside the
write reservation. Newly damaged resources are discarded and batches rebuilt;
the final verification time is recorded in terminal progress. Changed resources
lose their classifications; healthy sibling resources remain available. Code
changes after submission fail the run rather than silently changing its method.
Code fingerprint ordering is independent of process locale/collation. Registered
originals are application-immutable; external filesystem writes after the recorded
verification point are outside the application's transaction boundary and do not
rewrite the historical snapshot that was assessed.

All mapping, row, check, finding and finding-target frames are bulk-appended once
per table. No per-finding insertion loop holds the writer lock. Final family
progress shares the result transaction and reflects invalidation/cancellation;
stale pattern counts and per-key details are absent from coverage summaries.

Queued cancellation prevents a late claim. Running cancellation is a persistent,
cooperative request; no partial scientific output is accepted, including a request
arriving just before atomic result commit. Terminal runs cannot restart in place.

App-owned process handles survive browser-session closure. The supervisor assesses
only its own exited children. A restarted app can explicitly recover a stopped
claimed worker after checking PID plus birth time with `ps`; an active or
uninspectable process is never treated as proven stopped. Opening a repository or
another session does not interrupt pending work. Unclaimed queued work can be cancelled.
Launcher failures compare queued/unclaimed state under the same write reservation
as the failure event. The generic audit API cannot advance managed validations.

## Presentation and history

Validation runs apply to all files of the selected source version and the exact
displayed saved configuration. Buttons carry server-issued context/request IDs;
stale selections cannot target another source. Mapping suggestions still require
the existing explicit Missing information approval workflow.

Results query immutable SQL tables with stable pagination and bound parameters.
The UI does not load all row details or reread current source/parser state to
display history. Summary status counts describe materialised classification
records; mapping coverage separately discloses unknown/unevaluated/unclassified
populations. Candidate pattern memberships are not mutually exclusive row totals.
Removed sources and older configurations retain their saved runs. Run completion
is not a dataset pass, and lexical recognition does not certify calendar validity.
The Validation panel follows pending work submitted in other sessions while the
Results selection remains independent. A requested Results selection is retained
until acknowledged by the browser; unchanged choices are not resent each poll.

This increment does not add a review-decision workflow, exports, general type/
required-field rules, calendar checks, harmonisation or integration. Task 2F owns
the broader integrated acceptance gate; later tasks own those scientific features.
