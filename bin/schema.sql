-- Graph store. Derived from source, gitignored, rebuildable in seconds.
-- Nothing here is a source of truth: if it is wrong, delete the file and re-run bin/index.sh.

PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS node (
  repo TEXT NOT NULL,
  name TEXT NOT NULL,   -- fully-qualified constant, e.g. AchPulls::CreateService
  path TEXT,
  line INTEGER,
  PRIMARY KEY (repo, name)   -- NOT name alone: treasury and venture both define
);                           -- CustomerAccount, and a bare name key destroys one

CREATE TABLE IF NOT EXISTS edge (
  src  TEXT NOT NULL,
  dst  TEXT NOT NULL,
  repo TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'references'
);

-- Concept layer. theme.slug is the [repo, slug] key: [treasury, ach_pull].
CREATE TABLE IF NOT EXISTS theme (
  id                INTEGER PRIMARY KEY,
  repo              TEXT NOT NULL,
  slug              TEXT NOT NULL,
  last_indexed_sha  TEXT,
  UNIQUE (repo, slug)
);

CREATE TABLE IF NOT EXISTS theme_file (
  theme_id INTEGER NOT NULL REFERENCES theme(id) ON DELETE CASCADE,
  path     TEXT NOT NULL,
  UNIQUE (theme_id, path)
);

CREATE TABLE IF NOT EXISTS theme_node (
  theme_id INTEGER NOT NULL REFERENCES theme(id) ON DELETE CASCADE,
  name     TEXT NOT NULL,
  UNIQUE (theme_id, name)
);

CREATE INDEX IF NOT EXISTS i_edge_src  ON edge(src, repo);
CREATE INDEX IF NOT EXISTS i_edge_dst  ON edge(dst, repo);
CREATE INDEX IF NOT EXISTS i_node_repo ON node(repo);
