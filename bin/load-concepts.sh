#!/bin/zsh
# Rebuild theme, theme_file and theme_node from concepts/<repo>/*.md.
# Usage: load-concepts.sh <db> <repo-path>
set -uo pipefail
here=${0:A:h}
prog=${0:t}
source $here/graph-lib.zsh

usage() {
  print -u2 "usage: load-concepts.sh <db> <repo-path>    load concepts/<repo>/*.md into the theme tables"
  print -u2 ""
  print -u2 "The markdown is the source of truth; the theme tables are a cache. index.sh rebuilds"
  print -u2 "node and edge, this rebuilds the rest. Concepts with no markdown file are left alone."
  print -u2 ""
  print -u2 "exit: 0 clean, 2 usage, 1 error"
  exit 2
}

db=${1:-}; repo=${2:-}
[[ -n $db && -n $repo ]] || usage
shift 2
(( $# == 0 )) || usage

resolve_repo
refuse_linked_worktree "$main_worktree"

# checked before schema.sql runs: sql() creates the file, so a typo'd path used to be
# silently populated, and an unrelated sqlite file silently gained six tables and WAL.
[[ -f $db ]] || die "no such db: $db — run bin/index.sh first"
graph_db_present || die "$db has no node table — it is not a graph db; run bin/index.sh first"

concepts_dir=${CONCEPTS_DIR:-${here:h}/concepts}/$name
[[ -d $concepts_dir ]] || die "no such directory: $concepts_dir — run bin/seed-concepts.rb first"

files=( $concepts_dir/*.md(.N) )
(( ${#files} > 0 )) || die "no concept files in $concepts_dir — run bin/seed-concepts.rb first"

sql < "$here/schema.sql" > /dev/null || die "could not initialise schema in $db"
health_table_present || die "graph_health in $db is not the shape theme.sh writes"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT INT TERM HUP

for f in "${files[@]}"; do
  slug=${${f:t}%.md}
  [[ $slug != *[^A-Za-z0-9._-]* ]] \
    || die "unsafe slug from $f: ${slug//[^A-Za-z0-9._-]/?} — it is printed into the status TSV a hook parses"
done

ruby "$here/read-concepts.rb" "${files[@]}" > $tmp/fields.tsv 2> $tmp/read.err \
  || { cat $tmp/read.err >&2; die "refusing to load $name — bin/seed-concepts.rb regenerates a machine block it can read" }

loaded=0 where="" current=""
{
  print -r -- "BEGIN IMMEDIATE;"
  while IFS=$'\t' read -r slug kind value; do
    if [[ $kind != concept ]]; then
      [[ -n $where && $slug == $current ]] || die "$concepts_dir/$slug.md: a '$kind' row arrived before its own concept row — refusing, it would land on '$current'"
    fi
    case $kind in
      concept)
        [[ $value == "$name, $slug" ]] \
          || die "$concepts_dir/$slug.md declares 'concept: [$value]' but its name says [$name, $slug] — refusing to load a file that disagrees with itself"
        where="repo = $(quote "$name") AND slug = $(quote "$slug")"
        current=$slug
        print -r -- "INSERT OR IGNORE INTO theme(repo, slug) VALUES ($(quote "$name"), $(quote "$slug"));"
        print -r -- "DELETE FROM theme_file WHERE theme_id IN (SELECT id FROM theme WHERE $where);"
        print -r -- "DELETE FROM theme_node WHERE theme_id IN (SELECT id FROM theme WHERE $where);"
        loaded=$(( loaded + 1 ))
        ;;
      indexed)
        [[ $value != *[^0-9a-fA-F]* ]] \
          || die "$concepts_dir/$slug.md has no usable indexed sha: '${value//[^0-9a-zA-Z]/?}'"
        print -r -- "UPDATE theme SET last_indexed_sha = $(quote "$value") WHERE $where;"
        ;;
      file)
        print -r -- "INSERT OR IGNORE INTO theme_file(theme_id, path) SELECT id, $(quote "$value") FROM theme WHERE $where;"
        ;;
      symbol)
        print -r -- "INSERT OR IGNORE INTO theme_node(theme_id, name) SELECT id, $(quote "$value") FROM theme WHERE $where;"
        ;;
    esac
  done < $tmp/fields.tsv
  print -r -- "COMMIT;"
} > $tmp/load.sql

sqlite3 -cmd '.timeout 5000' -bail "$db" < $tmp/load.sql || die "load failed for $name"

landed=$(sql -separator ' ' "SELECT
  (SELECT count(*) FROM theme_node d JOIN theme t ON t.id = d.theme_id WHERE t.repo = $(quote "$name")),
  (SELECT count(*) FROM theme_file f JOIN theme t ON t.id = f.theme_id WHERE t.repo = $(quote "$name")),
  (SELECT count(*) FROM theme WHERE repo = $(quote "$name"))") || die "could not count what landed in $db"
print "loaded $loaded concepts into $db: ${landed[(w)1]} symbols, ${landed[(w)2]} files across ${landed[(w)3]} themes in $name"
if (( loaded != landed[(w)3] )); then
  print -u2 "$prog: $loaded file(s) loaded but $name has ${landed[(w)3]} theme(s) — the tables hold themes with no markdown file"
fi
