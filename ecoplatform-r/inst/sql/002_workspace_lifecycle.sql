-- Workspace membership is a projection; source manifests remain immutable.
CREATE TABLE workspace_lifecycle_events (
  event_id TEXT PRIMARY KEY NOT NULL,
  version_id TEXT NOT NULL REFERENCES dataset_versions(version_id),
  revision INTEGER NOT NULL CHECK(revision > 0),
  state TEXT NOT NULL CHECK(state IN ('active','removed')),
  request_id TEXT NOT NULL UNIQUE,
  request_hash TEXT NOT NULL,
  actor_id TEXT NOT NULL,
  reason TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(version_id, revision)
)
-- statement
CREATE TRIGGER workspace_lifecycle_events_update_immutable BEFORE UPDATE ON workspace_lifecycle_events BEGIN SELECT RAISE(ABORT, 'immutable history'); END
-- statement
CREATE TRIGGER workspace_lifecycle_events_delete_immutable BEFORE DELETE ON workspace_lifecycle_events BEGIN SELECT RAISE(ABORT, 'immutable history'); END
