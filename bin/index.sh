#!/bin/zsh
# Build the graph for a repo and load it into SQLite, end to end.
# Usage: index.sh <repo-path> [db-path]
set -uo pipefail
here=${0:A:h}
repo=${1:?repo path}
db=${2:-${here:h}/index/graph.db}

g() { env -u GIT_DIR -u GIT_WORK_TREE git "$@" }

# .git is a FILE in a linked worktree, so test the command not the path shape
g -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { print -u2 "not a git repo: $repo"; exit 1 }

main=$(g -C "$repo" worktree list --porcelain 2>/dev/null | sed -n '1s|^worktree ||p')
[ -n "$main" ] || { print -u2 "could not resolve the main worktree for $repo"; exit 1 }

# Refuse a linked worktree. `worktree list | head -1` answers with the PARENT, which
# is right for resolving a memory scope and wrong for deciding what to index: labelling
# worktree content as the parent repo would DELETE the main checkout's rows and replace
# them. The design's answer is main plus a per-session diff overlay; the overlay is not
# built yet, so refuse rather than silently clobber.
if [ "${main:A}" != "${repo:A}" ]; then
  print -u2 "refusing: $repo is a linked worktree of $main"
  print -u2 "index the main checkout instead; per-worktree overlay is not implemented"
  exit 1
fi

name=${main:t}
# $name reaches SQL. A directory named \"zz'; DROP TABLE node; --\" executed exactly that
# and the script still exited 0, so validate rather than escape.
if [[ ! "$name" =~ '^[A-Za-z0-9._-]+$' ]]; then
  print -u2 "refusing: repo name '$name' has characters that cannot reach SQL safely"
  exit 1
fi

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
files=$(g -C "$repo" ls-files app lib backend 2>/dev/null | grep -E '\.rb$')
[ -n "$files" ] || { print -u2 "no ruby files under app/lib/backend in $repo"; exit 1 }

print "indexing $name ($(print -r -- "$files" | wc -l | tr -d ' ') ruby files)"
( cd "$repo" && GRAPH_OUT="$tmp" ruby "$here/build-graph.rb" ${(f)files} >/dev/null ) \
  || { print -u2 "build-graph.rb failed"; exit 1 }
[ -s "$tmp/graph-nodes.tsv" ] || { print -u2 "no nodes produced"; exit 1 }

mkdir -p "${db:h}" || exit 1
sqlite3 "$db" < "$here/schema.sql" >/dev/null || { print -u2 "schema failed"; exit 1 }
sqlite3 "$db" "DELETE FROM node WHERE repo='$name'; DELETE FROM edge WHERE repo='$name';" \
  || { print -u2 "clearing old rows for '$name' failed"; exit 1 }

sqlite3 "$db" <<SQL || { print -u2 "load failed"; exit 1 }
CREATE TEMP TABLE n_raw(name TEXT, path TEXT, line INTEGER);
CREATE TEMP TABLE e_raw(src TEXT, dst TEXT);
.mode tabs
.import $tmp/graph-nodes.tsv n_raw
.import $tmp/graph-edges.tsv e_raw
INSERT OR REPLACE INTO node(repo, name, path, line) SELECT '$name', name, path, line FROM n_raw;
INSERT INTO edge(src, dst, repo, kind) SELECT src, dst, '$name', 'references' FROM e_raw;
SQL

n=$(sqlite3 "$db" "SELECT count(*) FROM node WHERE repo='$name'") || exit 1
e=$(sqlite3 "$db" "SELECT count(*) FROM edge WHERE repo='$name'") || exit 1
# an empty or zero count means the load silently did nothing — do not print success
[[ "$n" =~ '^[0-9]+$' && "$e" =~ '^[0-9]+$' && "$n" -gt 0 ]] \
  || { print -u2 "load produced no rows (nodes='$n' edges='$e')"; exit 1 }

print "loaded $n nodes, $e edges into $db"
print "query with: bin/rank.sh '$db' '<Symbol>'"
