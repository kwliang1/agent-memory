-- Graph store. Gitignored. NOT uniformly disposable — the two halves differ, and an
-- earlier version of this header said otherwise, which would have cost someone their
-- seeded themes.
--
--   node, edge                 DERIVED from Ruby source. bin/index.sh rebuilds them in
--                              under a second. Safe to delete; safe to wipe per repo.
--   graph_health               CLEARED by bin/index.sh, never written by it — theme.sh
--                              is the writer. A rebuild resets it; it is not restored.
--   theme, theme_file,         NOT derivable. Seeded by a model pass and reviewed by
--   theme_node                 hand. index.sh does not touch them. Deleting this file
--                              destroys them, and the path lists exist nowhere else.
--
-- REQUIREMENT this implies: a seeded theme must be persisted as markdown in git (the
-- concept template in SPEC.md), with these tables acting as a cache derived from those
-- files. Until that lands, back the db up before deleting it. Verified: seed a theme,
-- delete the db, re-run index.sh -> 2,049 nodes restored, 0 themes.

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

-- Per-symbol record of what a partial reparse dropped and could not account for.
-- A partial parse cannot distinguish a rename from a symbol still living in a file it
-- did not read, so it records rather than guesses.
--
-- Per-symbol rather than per-repo so `status` can name what is missing instead of only
-- asserting the repo is unhealthy. These rows are reporting detail, NOT the clearing
-- condition: bin/index.sh clears them on a full rebuild, because an "is the symbol back
-- yet" check would strand a repo forever after a rename, and rename is the commonest
-- trigger.
--
-- Lives here rather than in theme.sh because CREATE TABLE IF NOT EXISTS never migrates:
-- a table created by a sibling script makes an older db unreadable by a newer one, with
-- no migration owner.
CREATE TABLE IF NOT EXISTS graph_health (
  repo   TEXT NOT NULL,
  slug   TEXT NOT NULL,   -- the theme whose reseed dropped it
  symbol TEXT NOT NULL,   -- the specific symbol that went missing
  UNIQUE (repo, symbol)
);

-- What commit the structural half was built from. A session hook has to answer "is this
-- graph current" without paying for a rebuild to find out, and nothing else records it:
-- theme.last_indexed_sha is per concept and says nothing about node/edge.
--
-- Written inside the same transaction as the load, so it cannot disagree with the rows
-- it describes. A stamp written afterwards survives a load that failed, and a rebuild
-- that errors out would then read as fresh forever.
CREATE TABLE IF NOT EXISTS graph_stamp (
  repo     TEXT PRIMARY KEY,
  head_sha TEXT NOT NULL,
  built_at TEXT NOT NULL
);
