-- Ranked retrieval. Traverse to RANK, not to collect.
--
-- Naive 2-hop undirected reach on treasury: up to 980 of 2,049 nodes (48% of the
-- repo, ~196,000 tokens). Ranked top-10 is ~2,000. That gap is the whole reason
-- this file exists.
--
-- Weight: each hop divides by 1 + log(1 + in_degree(target)), so a generic node
-- contributes little and a specific collaborator dominates. The `1 +` is load
-- bearing: without it, an in-degree-0 target divides by log(1) = 0.
--
-- Params: :start (node name), :depth (2), :k (10), :repo (repo name)
--
-- Scoped to one repo. Without the filter, two repos that both define a class name
-- would traverse into each other through the collision rather than through a real
-- cross-repo edge.

CREATE TEMP VIEW IF NOT EXISTS und AS
  SELECT src AS i, dst AS o FROM edge WHERE repo = :repo
  UNION ALL
  SELECT dst AS i, src AS o FROM edge WHERE repo = :repo;

CREATE TEMP VIEW IF NOT EXISTS indeg AS
  SELECT dst AS n, count(*) AS d FROM edge WHERE repo = :repo GROUP BY dst;

WITH RECURSIVE reach(id, depth, w) AS (
  SELECT :start, 0, 1.0
  UNION ALL
  SELECT u.o, r.depth + 1, r.w / (1.0 + log(1 + COALESCE(i.d, 0)))
  FROM und u
  JOIN reach r ON u.i = r.id
  LEFT JOIN indeg i ON i.n = u.o
  WHERE r.depth < :depth
)
SELECT r.id            AS related,
       round(sum(r.w), 3) AS score,
       min(r.depth)    AS hops,
       n.path          AS path,
       n.line          AS line
FROM reach r
LEFT JOIN node n ON n.name = r.id AND n.repo = :repo
WHERE r.id <> :start
GROUP BY r.id
ORDER BY score DESC, related
LIMIT :k;
