CREATE TABLE validation_requests (
 operation_id TEXT PRIMARY KEY NOT NULL REFERENCES operations(operation_id),
 request_json TEXT NOT NULL CHECK(json_valid(request_json)), request_hash TEXT NOT NULL,
 frozen_json TEXT NOT NULL CHECK(json_valid(frozen_json)), frozen_hash TEXT NOT NULL
)
-- statement
CREATE TABLE validation_claims (
 operation_id TEXT PRIMARY KEY NOT NULL REFERENCES validation_requests(operation_id),
 worker_token TEXT NOT NULL, pid INTEGER NOT NULL, process_started REAL NOT NULL, created_at TEXT NOT NULL
)
-- statement
CREATE TABLE validation_cancellations (
 operation_id TEXT PRIMARY KEY NOT NULL REFERENCES validation_requests(operation_id),
 actor_id TEXT NOT NULL, reason TEXT NOT NULL, created_at TEXT NOT NULL
)
-- statement
CREATE TABLE validation_progress (
 operation_id TEXT NOT NULL REFERENCES validation_requests(operation_id), sequence INTEGER NOT NULL,
 family TEXT NOT NULL, status TEXT NOT NULL, message TEXT NOT NULL, created_at TEXT NOT NULL,
 PRIMARY KEY(operation_id, sequence)
)
-- statement
CREATE TABLE validation_results (
 operation_id TEXT PRIMARY KEY NOT NULL REFERENCES validation_requests(operation_id),
 payload_json TEXT NOT NULL CHECK(json_valid(payload_json)), result_hash TEXT NOT NULL
)
-- statement
CREATE TABLE validation_mappings (
 operation_id TEXT NOT NULL REFERENCES validation_results(operation_id), family TEXT NOT NULL,
 mapping_index INTEGER NOT NULL, mapping_id TEXT, table_id TEXT, status TEXT NOT NULL,
 population_count INTEGER, evaluated_count INTEGER NOT NULL,
 summary_json TEXT NOT NULL CHECK(json_valid(summary_json)),
 detail_json TEXT NOT NULL CHECK(json_valid(detail_json)),
 PRIMARY KEY(operation_id, family, mapping_index)
)
-- statement
CREATE TABLE validation_rows (
 operation_id TEXT NOT NULL, family TEXT NOT NULL, mapping_index INTEGER NOT NULL,
 row_number INTEGER NOT NULL, status TEXT NOT NULL, table_id TEXT NOT NULL,
 record_json TEXT NOT NULL CHECK(json_valid(record_json)),
 PRIMARY KEY(operation_id, family, mapping_index, row_number),
 FOREIGN KEY(operation_id, family, mapping_index) REFERENCES validation_mappings(operation_id, family, mapping_index)
)
-- statement
CREATE TABLE validation_checks (
 check_id TEXT PRIMARY KEY NOT NULL, operation_id TEXT NOT NULL, family TEXT NOT NULL,
 mapping_index INTEGER NOT NULL, rule_id TEXT NOT NULL, record_json TEXT NOT NULL CHECK(json_valid(record_json)),
 FOREIGN KEY(operation_id, family, mapping_index) REFERENCES validation_mappings(operation_id, family, mapping_index)
)
-- statement
CREATE TABLE validation_findings (
 finding_id TEXT PRIMARY KEY NOT NULL, operation_id TEXT NOT NULL, family TEXT NOT NULL,
 mapping_index INTEGER NOT NULL, rule_id TEXT NOT NULL, severity TEXT NOT NULL,
 record_json TEXT NOT NULL CHECK(json_valid(record_json)),
 FOREIGN KEY(operation_id, family, mapping_index) REFERENCES validation_mappings(operation_id, family, mapping_index)
)
-- statement
CREATE TABLE validation_finding_targets (
 finding_id TEXT NOT NULL REFERENCES validation_findings(finding_id), row_locator TEXT NOT NULL,
 original_value TEXT NOT NULL, PRIMARY KEY(finding_id, row_locator)
)
-- statement
CREATE INDEX validation_rows_filter_idx ON validation_rows(operation_id, family, status, mapping_index, row_number)
-- statement
CREATE INDEX validation_findings_filter_idx ON validation_findings(operation_id, severity, rule_id)
