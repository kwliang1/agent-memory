#!/bin/zsh
# Build the graph for a repo and load it into SQLite, end to end.
# Usage: index.sh <repo-path> [db-path]
set -uo pipefail
here=${0:A:h}
repo=${1:?repo path}
db=${2:-${here:h}/index/graph.db}

g() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR git "$@" }

# .git is a FILE in a linked worktree, so test the command not the path shape
g -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { print -u2 "not a git repo: $repo"; exit 1 }

main=$(g -C "$repo" worktree list --porcelain 2>/dev/null | sed -n '1s|^worktree ||p')
[ -n "$main" ] || { print -u2 "could not resolve the main worktree for $repo"; exit 1 }

# Refuse a linked worktree. `worktree list | head -1` answers with the PARENT, which
# is right for resolving a memory scope and wrong for deciding what to index: labelling
# worktree content as the parent repo would DELETE the main checkout's rows and replace
# them. The design's answer is main plus a per-session diff overlay; the overlay is not
# built yet, so refuse rather than silently clobber.
#
# The one exception is a clean worktree sitting exactly at origin/main: that IS the parent's
# content, and it is how bin/reindex.sh builds without touching the shared checkout.
if [ "${main:A}" != "${repo:A}" ]; then
  if [ "${MEMORY_INDEX_CANONICAL:-}" = 1 ]; then
    tip=$(g -C "$main" rev-parse --verify 'origin/main^{commit}' 2>/dev/null)
    if [ -z "$tip" ] || [ "$tip" != "$(g -C "$repo" rev-parse --verify 'HEAD^{commit}' 2>/dev/null)" ] \
       || [ -n "$(g -C "$repo" status --porcelain 2>/dev/null)" ]; then
      print -u2 "refusing: $repo is not a clean worktree at $main's origin/main"
      exit 1
    fi
  else
    print -u2 "refusing: $repo is a linked worktree of $main"
    print -u2 "index the main checkout instead; per-worktree overlay is not implemented"
    exit 1
  fi
fi

name=${main:t}
# $name reaches SQL. A directory named \"zz'; DROP TABLE node; --\" executed exactly that
# and the script still exited 0, so validate rather than escape.
if [[ ! "$name" =~ '^[A-Za-z0-9._-]+$' ]]; then
  print -u2 "refusing: repo name '$name' has characters that cannot reach SQL safely"
  exit 1
fi

head=$(g -C "$repo" rev-parse --verify HEAD^{commit} 2>/dev/null) \
  || { print -u2 "$repo has no commits — nothing to stamp the graph against"; exit 1 }

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
# Dispatch on which language the repo is mostly written in, not on which list is
# non-empty. "Ruby unless there is no Ruby" sent a TypeScript repo carrying one lib/*.rb
# tooling script to Prism, which indexed that one file and exited 0 -- the same "returns
# nothing, successfully" failure rank.sh is fixed for below. Both counts are taken over
# the whole repo: counting .rb under app/lib/backend against .ts anywhere sent a Rails
# engines layout to the TypeScript parser, since its models live in engines/*/app/models.
#
# core.quotePath=true is PINNED, not inherited: bin/theme.sh:102 pins it too, and with
# quotePath=false in a repo's own config this listing widened while theme.sh's did not --
# the same permanently-unstampable theme, reached through configuration.
#
# A path git has to quote -- non-ASCII, or a tab/newline/quote/backslash in the name --
# is left quoted, so the extension filters below skip it. That is the shipped design,
# not an oversight: bin/theme.sh's ensure_indexer_visible() models the indexer's
# visibility as exactly this listing and refuses to seed a concept over anything
# outside it, naming the reason. Widening one side without the other left a non-ASCII
# theme reading stale forever, with reseed unable to stamp it.
# --deduplicate because an unresolved merge lists a conflicted path once per stage,
# which both inflates the count and reads as a module-name collision.
all=$(g -C "$repo" -c core.quotePath=true ls-files --deduplicate 2>/dev/null) \
  || { print -u2 "could not list tracked files in $repo"; exit 1 }
nrb=$(print -rn -- "$all" | grep -cE '\.rb$') || true
# Tests are excluded, as scoping Ruby to app/lib/backend already excludes spec/: they are
# 120 of hydra's 230 files, and because the ranker traverses UNDIRECTED they bridge
# modules that never reference each other -- BridgeDispatch answered Config instead of
# BridgeServer with them in. (^|/)tests?/ rather than ^tests?/, because the monorepo
# shape is <pkg>/test/: 323 files in nova. A .d.ts states types and no runtime
# dependency, so it would add a module nothing can reach.
ts=$(print -rn -- "$all" \
  | grep -E '\.(ts|tsx|mts|cts)$' \
  | grep -Ev '\.d\.(ts|mts|cts)$|(^|/)node_modules/|(^|/)__tests__/|(^|/)tests?/|(^|/)([^/]*[-_])?e2e/|\.(test|spec)\.')
nts=$(print -rn -- "$ts" | grep -c .) || true
# nrb counts specs and nts does not, so the comparison is approximate -- and two repos on
# this machine DO sit inside that margin: flowdash is 1,465 .rb repo-wide against 871
# under app/lib/backend and 880 kept .ts, and noto is 143/74/82. Both are Rails apps with
# a JS frontend, so the repo-wide count is the one that answers correctly; scoping it
# would send them to the TypeScript parser. venture (14,650 / 9,808 / 6,023) is not close.
# A tie goes to Ruby, which is arbitrary but has to go somewhere.

if (( nrb == 0 && nts == 0 )); then
  print -u2 "nothing to index in $repo: no .rb, and no .ts/.tsx/.mts/.cts outside"
  print -u2 "node_modules, tests and .d.ts"
  exit 1
elif (( nrb >= nts )); then
  lang=ruby; skipped=$nts; runner=(ruby "$here/build-graph.rb")
  # Counted repo-wide, but Prism is still only pointed at the conventional Rails paths.
  files=$(print -rn -- "$all" | grep -E '^(app|lib|backend)/.*\.rb$')
  [ -n "$files" ] || {
    print -u2 "$repo reads as Ruby ($nrb .rb files) but none are under app/lib/backend,"
    print -u2 "which is the only tree build-graph.rb indexes"
    exit 1
  }
  count=$(print -rn -- "$files" | grep -c .) || true
else
  lang=typescript; files=$ts; count=$nts
  # what Prism would actually have been given, not every .rb in the repo
  skipped=$(print -rn -- "$all" | grep -cE '^(app|lib|backend)/.*\.rb$') || true
  runner=(bun run "$here/build-graph-ts.ts")
  whence -p bun >/dev/null 2>&1 \
    || { print -u2 "bun is required to index TypeScript and is not on PATH"; exit 1 }
fi

print "indexing $name ($count $lang files)"
# Say what was passed over, so a repo indexed as the wrong language is visible rather
# than silent.
if (( skipped > 0 )); then
  print "  (skipped $skipped file$( (( skipped == 1 )) || print s ) of the other language)"
fi
if [ "$lang" = ruby ] && (( nrb > count )); then
  print "  (and $(( nrb - count )) .rb outside app/lib/backend, which Prism is not pointed at)"
fi
manifests=$(print -rn -- "$all" | grep -E '(^|/)package\.json$' | grep -Ev '(^|/)node_modules/')
( cd "$repo" && GRAPH_OUT="$tmp" GRAPH_MANIFESTS="$manifests" $runner ${(f)files} >/dev/null ) \
  || { print -u2 "${runner[-1]:t} failed"; exit 1 }
[ -s "$tmp/graph-nodes.tsv" ] || { print -u2 "no nodes produced"; exit 1 }
ruby "$here/structural.rb" "$tmp/graph-nodes.tsv" "$tmp/graph-edges.tsv" > "$tmp/graph-structural.tsv" \
  || { print -u2 "structural.rb failed"; exit 1 }

mkdir -p "${db:h}" || exit 1
sqlite3 -cmd '.timeout 10000' "$db" < "$here/schema.sql" >/dev/null || { print -u2 "schema failed"; exit 1 }
# One transaction, one connection. Clearing in a separate sqlite3 call left the graph
# visibly EMPTY between the DELETE and the load: measured 8 of 264 concurrent reads
# during a rebuild returning 0 nodes, against 0 of 264 with no rebuild running. A hook
# that rebuilds at session start points that window straight at every other live
# session, which then retrieves nothing and says so silently.
#
# -bail matters as much as the transaction: without it a failed .import runs on to the
# COMMIT and commits a partial graph.
sqlite3 -bail -cmd '.timeout 10000' "$db" <<SQL || { print -u2 "load failed"; exit 1; }
BEGIN IMMEDIATE;
-- a full rebuild is the single clearing condition for graph_health: a live "is the
-- symbol back" check cannot be, because a RENAMED symbol never returns and would
-- strand the repo as incomplete forever.
DELETE FROM node WHERE repo='$name';
DELETE FROM edge WHERE repo='$name';
DELETE FROM graph_health WHERE repo='$name';
DELETE FROM structural_node WHERE repo='$name';
CREATE TEMP TABLE n_raw(name TEXT, path TEXT, line INTEGER);
CREATE TEMP TABLE e_raw(src TEXT, dst TEXT, kind TEXT);
CREATE TEMP TABLE s_raw(name TEXT);
.mode tabs
.import $tmp/graph-nodes.tsv n_raw
.import $tmp/graph-edges.tsv e_raw
.import $tmp/graph-structural.tsv s_raw
INSERT OR REPLACE INTO node(repo, name, path, line) SELECT '$name', name, path, line FROM n_raw;
INSERT INTO edge(src, dst, repo, kind) SELECT src, dst, '$name', COALESCE(NULLIF(kind,''),'references') FROM e_raw;
INSERT OR IGNORE INTO structural_node(repo, name) SELECT '$name', name FROM s_raw;
INSERT OR REPLACE INTO graph_stamp(repo, head_sha) VALUES ('$name', '$head');
COMMIT;
SQL

n=$(sqlite3 -cmd '.timeout 10000' "$db" "SELECT count(*) FROM node WHERE repo='$name'") || exit 1
e=$(sqlite3 -cmd '.timeout 10000' "$db" "SELECT count(*) FROM edge WHERE repo='$name'") || exit 1
# an empty or zero count means the load silently did nothing — do not print success
[[ "$n" =~ '^[0-9]+$' && "$e" =~ '^[0-9]+$' && "$n" -gt 0 ]] \
  || { print -u2 "load produced no rows (nodes='$n' edges='$e')"; exit 1 }

print "loaded $n nodes, $e edges into $db"
print "query with: bin/rank.sh '$db' '<Symbol>'"
