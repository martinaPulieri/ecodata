-- Each block is a single DBI statement. Triggers are installed by migration code.
CREATE TABLE datasets (
  dataset_id TEXT PRIMARY KEY NOT NULL,
  created_at TEXT NOT NULL
)
-- statement
CREATE TABLE dataset_versions (
  version_id TEXT PRIMARY KEY NOT NULL,
  dataset_id TEXT NOT NULL REFERENCES datasets(dataset_id),
  parent_version_id TEXT REFERENCES dataset_versions(version_id),
  metadata_json TEXT NOT NULL CHECK(json_valid(metadata_json)),
  created_at TEXT NOT NULL
)
-- statement
CREATE TABLE resources (
  resource_id TEXT PRIMARY KEY NOT NULL,
  version_id TEXT NOT NULL REFERENCES dataset_versions(version_id),
  ordinal INTEGER NOT NULL CHECK(ordinal > 0),
  original_name TEXT NOT NULL,
  owned_relative_path TEXT NOT NULL UNIQUE,
  sha256 TEXT NOT NULL,
  size_bytes REAL NOT NULL CHECK(size_bytes >= 0),
  acquisition_status TEXT NOT NULL CHECK(acquisition_status IN ('complete','incomplete','unknown')),
  integrity_status TEXT NOT NULL CHECK(integrity_status = 'verified'),
  UNIQUE(version_id, ordinal)
)
-- statement
CREATE TABLE configuration_revisions (
  config_id TEXT PRIMARY KEY NOT NULL,
  version_id TEXT NOT NULL REFERENCES dataset_versions(version_id),
  revision INTEGER NOT NULL CHECK(revision > 0),
  parent_config_id TEXT REFERENCES configuration_revisions(config_id),
  payload_json TEXT NOT NULL CHECK(json_valid(payload_json)),
  context_hash TEXT NOT NULL,
  actor_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(version_id, revision),
  UNIQUE(config_id, version_id)
)
-- statement
CREATE TABLE operations (
  operation_id TEXT PRIMARY KEY NOT NULL,
  version_id TEXT NOT NULL REFERENCES dataset_versions(version_id),
  config_id TEXT NOT NULL,
  operation_type TEXT NOT NULL CHECK(operation_type IN ('inspect','validation')),
  request_id TEXT NOT NULL UNIQUE,
  request_hash TEXT NOT NULL,
  actor_id TEXT NOT NULL,
  environment_json TEXT NOT NULL CHECK(json_valid(environment_json)),
  created_at TEXT NOT NULL,
  FOREIGN KEY(config_id, version_id) REFERENCES configuration_revisions(config_id, version_id)
)
-- statement
CREATE TABLE operation_events (
  event_id TEXT PRIMARY KEY NOT NULL,
  operation_id TEXT NOT NULL REFERENCES operations(operation_id),
  sequence INTEGER NOT NULL CHECK(sequence > 0),
  status TEXT NOT NULL CHECK(status IN ('queued','running','completed','completed_with_limitations','failed','interrupted','cancelled')),
  actor_id TEXT NOT NULL,
  reason TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(operation_id, sequence)
)
-- statement
CREATE INDEX resources_version_idx ON resources(version_id)
-- statement
CREATE INDEX operations_version_idx ON operations(version_id, created_at)
