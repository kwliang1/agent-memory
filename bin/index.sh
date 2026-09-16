#!/bin/zsh
# Build the graph for a repo and load it into SQLite, end to end.
# Usage: index.sh <repo-path> [db-path]
set -uo pipefail
here=${0:A:h}
repo=${1:?repo path}
db=${2:-${here:h}/index/graph.db}

[ -d "$repo/.git" ] || { print -u2 "not a git repo: $repo"; exit 1; }
name=$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$repo" worktree list --porcelain 2>/dev/null \
       | sed -n '1s|^worktree ||p'); name=${name:t}
[ -n "$name" ] || { print -u2 "could not resolve repo name for $repo"; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
files=$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$repo" ls-files app lib backend 2>/dev/null | grep -E '\.rb$')
[ -n "$files" ] || { print -u2 "no ruby files under app/lib/backend in $repo"; exit 1; }

print "indexing $name ($(print -r -- "$files" | wc -l | tr -d ' ') ruby files)"
( cd "$repo" && GRAPH_OUT="$tmp" ruby "$here/build-graph.rb" ${(f)files} ) || exit 1

mkdir -p "${db:h}"
sqlite3 "$db" < "$here/schema.sql" || exit 1
sqlite3 "$db" "DELETE FROM node WHERE repo='$name'; DELETE FROM edge WHERE repo='$name';"

# stage the TSVs, then project them in with the repo column
sqlite3 "$db" <<SQL
CREATE TEMP TABLE n_raw(name TEXT, path TEXT, line INTEGER);
CREATE TEMP TABLE e_raw(src TEXT, dst TEXT);
.mode tabs
.import $tmp/graph-nodes.tsv n_raw
.import $tmp/graph-edges.tsv e_raw
INSERT OR REPLACE INTO node(repo, name, path, line) SELECT '$name', name, path, line FROM n_raw;
INSERT INTO edge(src, dst, repo, kind) SELECT src, dst, '$name', 'references' FROM e_raw;
SQL

n=$(sqlite3 "$db" "SELECT count(*) FROM node WHERE repo='$name'")
e=$(sqlite3 "$db" "SELECT count(*) FROM edge WHERE repo='$name'")
print "loaded $n nodes, $e edges into $db"
print "query with: bin/rank.sh '$db' '<Symbol>'"
