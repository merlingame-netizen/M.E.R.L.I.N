-- D1 (SQLite) schema for merlin-svc. Apply with:
--   wrangler d1 execute merlin --remote --file=schema.sql
CREATE TABLE IF NOT EXISTS items (
  key        TEXT PRIMARY KEY,
  value      TEXT,
  updated_at INTEGER
);
