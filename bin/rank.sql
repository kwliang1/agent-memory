-- Ranked retrieval. Traverse to RANK, not to collect.
--
-- Naive 2-hop undirected reach on treasury: up to 980 of 2,049 nodes (48% of the
-- repo, ~196,000 tokens). Ranked top-10 is ~2,000. That gap is the whole reason
-- this file exists.
--
-- Weight: each hop divides by 1 + log(1 + undirected_degree(target)), so a generic node
-- contributes little and a specific collaborator dominates. The `1 +` is load
-- bearing: without it, an in-degree-0 target divides by log(1) = 0.
--
-- Params: :depth (2), :k (10), :repo (repo name), plus a TEMP TABLE seed(name)
-- holding one row per entry point. A concept resolves to several entry points and each
-- gives a different view, so the traversal seeds from all of them at once and the scores
-- sum: a node two entry points agree on outranks one only a single entry point reaches.
--
-- Scoped to one repo. Without the filter, two repos that both define a class name
-- would traverse into each other through the collision rather than through a real
-- cross-repo edge.

-- Framework base classes and GraphQL roots are not relations. Excluded HERE, in the
-- traversal, not at the final SELECT: filtering the answer still lets all 121 models
-- inheriting ApplicationRecord score through it at 2 hops. Filtering the edge stops it
-- acting as a relation at all, which is what "not a relation" has to mean.
--
-- NOT the same list as derive-concepts.rb, deliberately: that one excludes `Api`, and
-- Api::AchPullsController is a required answer per SPEC. ErrorTracker is also NOT here —
-- it is a Sentry wrapper whose 130 edges are deliberate call sites, so "where do we
-- report errors" stays answerable; log damping already gives it a 0.32 per-hop penalty.
CREATE TEMP VIEW IF NOT EXISTS structural AS
  SELECT name FROM node WHERE repo = :repo AND (
    name IN ('ApplicationRecord','ApplicationController','ApplicationJob','ApplicationService')
    OR name LIKE 'Types::%'
    OR name LIKE 'Mutations::Base%'
    OR name = 'Temporal::Schedules::Registry'
  );

CREATE TEMP VIEW IF NOT EXISTS und AS
  SELECT src AS i, dst AS o FROM edge WHERE repo = :repo
    AND src NOT IN (SELECT name FROM structural)
    AND dst NOT IN (SELECT name FROM structural)
  UNION ALL
  SELECT dst AS i, src AS o FROM edge WHERE repo = :repo
    AND src NOT IN (SELECT name FROM structural)
    AND dst NOT IN (SELECT name FROM structural);

-- UNDIRECTED degree, not in-degree. Traversal is undirected, so the weight must be too:
-- Types::QueryType has in-degree 1 and out-degree 105, so an in-degree weight gave a
-- GraphQL root the same near-zero penalty as a leaf, and it ranked 2nd from CustomerAccount.
-- Named `deg`, not `indeg`: the old name outlived the in-degree formula and put a wrong
-- definition into SPEC.
CREATE TEMP VIEW IF NOT EXISTS deg AS
  SELECT n, count(*) AS d FROM (
    SELECT src AS n FROM edge WHERE repo = :repo
    UNION ALL
    SELECT dst AS n FROM edge WHERE repo = :repo
  ) GROUP BY n;

WITH RECURSIVE reach(id, depth, w) AS (
  SELECT s.name, 0, 1.0 FROM seed s
  UNION ALL
  SELECT u.o, r.depth + 1, r.w / (1.0 + log(1 + COALESCE(g.d, 0)))
  FROM und u
  JOIN reach r ON u.i = r.id
  LEFT JOIN deg g ON g.n = u.o
  WHERE r.depth < :depth
)
-- Framework base classes are not relations. ApplicationRecord carries 121 reference
-- edges because every model inherits it, and ranked 4th from CustomerAccount.
-- derive-concepts.rb already excludes these at the concept layer; the symbol ranker
-- needs the same list.
SELECT r.id            AS related,
       round(sum(r.w), 3) AS score,
       min(r.depth)    AS hops,
       n.path          AS path,
       n.line          AS line
FROM reach r
LEFT JOIN node n ON n.name = r.id AND n.repo = :repo
WHERE r.id NOT IN (SELECT name FROM seed)
GROUP BY r.id
ORDER BY score DESC, related
LIMIT :k;
