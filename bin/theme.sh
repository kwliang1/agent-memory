#!/bin/zsh
set -uo pipefail
here=${0:A:h}
prog=${0:t}
source $here/graph-lib.zsh
indexer_dirs=(app lib backend)
indexer_pattern='\.rb$'

usage() {
  print -u2 "usage: theme.sh seed   <db> <repo-path> <slug> <path>...   create/replace a theme, stamp HEAD"
  print -u2 "       theme.sh status <db> <repo-path> [slug]             fresh|stale per theme, TSV"
  print -u2 "       theme.sh reseed <db> <repo-path> <slug>             re-read only what moved, re-stamp"
  print -u2 ""
  print -u2 "status TSV: repo slug state files changed last_indexed_sha reason"
  print -u2 "  state  = fresh | stale                       (field 3)"
  print -u2 "  reason = '' | never-indexed | unknown-sha | diff-failed | changed-files | graph-incomplete | no-files"
  print -u2 "status exits 0 for fresh, stale, and a db with no themes — read field 3, not"
  print -u2 "the code. It exits 1 for a slug that was never seeded, a missing db, and a db"
  print -u2 "with no schema, so a per-theme probe must handle all three."
  print -u2 ""
  print -u2 "exit: 0 clean, 2 usage, 1 error, 3 reseeded but symbols were dropped — run bin/index.sh"
  print -u2 "seed and reseed write the shared graph, so both refuse a linked worktree; status reads"
  print -u2 "and works anywhere."
  exit 2
}

theme_path() {
  local p=$1 abs=$1
  if [[ $p != /* ]]; then
    abs=$PWD/$p
    [[ -e $abs ]] || abs=${repo:A}/$p
  fi
  print -r -- ${${abs:A}#${repo:A}/}
}

theme_node_sql() {
  local tid=$1
  print -r -- "DELETE FROM theme_node WHERE theme_id = $tid;"
  print -r -- "INSERT OR IGNORE INTO theme_node(theme_id, name)"
  print -r -- "  SELECT $tid, n.name FROM node n"
  print -r -- "  JOIN theme_file f ON f.theme_id = $tid AND f.path = n.path"
  print -r -- "  WHERE n.repo = $(quote "$name");"
}

intersect() {
  awk 'NR == FNR { k[$0] = 1; next } ($0 in k)' "$1" "$2"
}

subtract() {
  local keys=$1 candidates=$2
  if [[ -s $keys ]]; then
    awk 'NR == FNR { k[$0] = 1; next } !($0 in k)' "$keys" "$candidates"
  else
    cat "$candidates"
  fi
}

ensure_tracked() {
  [[ -f $tmp/tracked.txt ]] && return 0
  git_repo ls-files > $tmp/tracked.txt || die "could not list tracked files in $repo"
}

ensure_scope() {
  [[ -f $tmp/scope.txt ]] && return 0
  git_repo ls-files "${indexer_dirs[@]}" > $tmp/scope-raw.txt \
    || die "could not list the indexer scope in $repo"
  grep -E "$indexer_pattern" $tmp/scope-raw.txt > $tmp/scope.txt
  (( $? <= 1 )) || die "could not filter the indexer scope in $repo"
  return 0
}

changed_files() {
  local sha=$1 theme_files=$2 out=$3
  : > "$out"
  [[ -n $sha ]] || { print -r -- never-indexed; return 0 }

  [[ $sha != *[^0-9a-fA-F]* ]] || { print -r -- unknown-sha; return 0 }
  local diff_file=$tmp/diff.$sha
  [[ -f $tmp/unresolvable.$sha ]] && { print -r -- unknown-sha; return 0 }
  if [[ ! -f $diff_file ]]; then
    if ! git_repo cat-file -e "${sha}^{commit}" 2>/dev/null; then
      : > $tmp/unresolvable.$sha
      print -r -- unknown-sha
      return 0
    fi
    if ! git_repo diff --name-only "$sha" -- > "$diff_file"; then
      rm -f "$diff_file"
      print -r -- diff-failed
      return 0
    fi
  fi
  CF_DIFF=$diff_file CF_GONE=$tmp/untracked-paths.txt awk '
    FILENAME == ENVIRON["CF_DIFF"] { d[$0] = 1; next }
    FILENAME == ENVIRON["CF_GONE"] { g[$0] = 1; next }
    !seen[$0]++ && (($0 in d) || ($0 in g))
  ' "$diff_file" $tmp/untracked-paths.txt "$theme_files" > "$out"
  print -r -- computed
}

ensure_indexer_visible() {
  [[ -f $tmp/quoted-tracked.txt ]] && return 0
  env -u GIT_DIR -u GIT_WORK_TREE git -C "$repo" -c core.quotePath=true ls-files > $tmp/quoted-tracked.txt \
    || die "could not list tracked files in $repo"
}

untracked_among() {
  ensure_indexer_visible
  subtract $tmp/quoted-tracked.txt "$1" > $tmp/untracked-paths.txt
}

graph_incomplete() {
  health_table_present || return 0
  local flagged
  flagged=$(sql "SELECT count(*) FROM graph_health WHERE repo = $(quote "$name")") \
    || die "could not read graph_health from $db"
  (( flagged ))
}

refuse_unread_stamp() {
  local slug=$1 theme_files=$2
  git_repo diff --name-only HEAD -- > $tmp/uncommitted.txt \
    || die "could not check for uncommitted changes in $repo"
  intersect $tmp/uncommitted.txt "$theme_files" > $tmp/dirty.txt
  [[ -s $tmp/dirty.txt ]] || return 0
  print -u2 "theme.sh: uncommitted changes in: $(paste -sd' ' - < $tmp/dirty.txt)"
  die "refusing to stamp $slug at HEAD — the graph cannot have read content HEAD does not carry"
}

parse_into_graph_nodes() {
  rm -f $tmp/graph-nodes.tsv
  ( cd "$repo" && GRAPH_OUT="$tmp" ruby "$here/build-graph.rb" "$@" ) > $tmp/parse.log 2>&1 \
    || { cat $tmp/parse.log >&2; die "build-graph.rb failed for $name/$slug" }
  [[ -f $tmp/graph-nodes.tsv ]] || die "build-graph.rb wrote no nodes for $name/$slug"
}

node_sync_sql() {
  local clear_list=$1
  local -A scope_paths
  local s
  while IFS= read -r s; do scope_paths[$s]=1; done < $tmp/scope.txt
  local p
  while IFS= read -r p; do
    print -r -- "DELETE FROM node WHERE repo = $(quote "$name") AND path = $(quote "$p");"
  done < "$clear_list"
  # a partial parse keeps only edges whose target it also parsed, so its edge set is wrong by construction
  local sym declared_in declared_at
  while IFS=$'\t' read -r sym declared_in declared_at; do
    [[ -n ${scope_paths[$declared_in]:-} ]] || die "refusing to load $sym: $declared_in is outside the indexer scope"
    print -r -- "INSERT INTO node(repo, name, path, line) VALUES ($(quote "$name"), $(quote "$sym"), $(quote "$declared_in"), $(quote "$declared_at"))"
    print -r -- "  ON CONFLICT(repo, name) DO UPDATE SET path = excluded.path, line = excluded.line"
    print -r -- "  WHERE node.line IS NULL OR (excluded.path, excluded.line) < (node.path, node.line);"
  done < $tmp/graph-nodes.tsv
}

cmd_seed() {
  local slug=${1:-}
  [[ -n $slug ]] || usage
  [[ $slug != *[^A-Za-z0-9._-]* ]] \
    || die "unsafe slug: ${slug//[^A-Za-z0-9._-]/?} — it is printed into the status TSV a hook parses"
  shift
  (( $# > 0 )) || usage
  refuse_linked_worktree "$main_worktree"

  local p
  for p in "$@"; do
    theme_path "$p"
  done | sort -u > $tmp/candidates.txt
  ensure_tracked
  subtract $tmp/tracked.txt $tmp/candidates.txt > $tmp/untracked.txt
  if [[ -s $tmp/untracked.txt ]]; then
    print -u2 "theme.sh: not tracked in $name: $(paste -sd' ' - < $tmp/untracked.txt)"
    die "refusing to seed $slug — an untracked path never appears in a diff and would read fresh forever"
  fi
  ensure_indexer_visible
  subtract $tmp/quoted-tracked.txt $tmp/candidates.txt > $tmp/invisible.txt
  if [[ -s $tmp/invisible.txt ]]; then
    print -u2 "theme.sh: bin/index.sh cannot read: $(paste -sd' ' - < $tmp/invisible.txt)"
    die "refusing to seed $slug — git quotes these names for the indexer, which skips them, so the theme would certify symbols the graph never receives"
  fi

  sql < "$here/schema.sql" > /dev/null || die "could not initialise schema in $db"
  refuse_unread_stamp "$slug" $tmp/candidates.txt
  ensure_scope
  intersect $tmp/scope.txt $tmp/candidates.txt > $tmp/seed-scope.txt
  : > $tmp/seed-parse.txt
  local f
  while IFS= read -r f; do
    [[ -f $repo/$f ]] && print -r -- "$f" >> $tmp/seed-parse.txt
  done < $tmp/seed-scope.txt
  if [[ -s $tmp/seed-parse.txt ]]; then
    parse_into_graph_nodes ${(f)"$(cat $tmp/seed-parse.txt)"}
  else
    : > $tmp/graph-nodes.tsv
  fi

  sql "INSERT OR IGNORE INTO theme(repo, slug) VALUES ($(quote "$name"), $(quote "$slug"));" \
    || die "could not create theme $name/$slug"
  local id
  id=$(sql "SELECT id FROM theme WHERE repo = $(quote "$name") AND slug = $(quote "$slug")") \
    || die "could not read theme $name/$slug"
  [[ -n $id ]] || die "could not create theme $name/$slug"

  {
    print -r -- "BEGIN IMMEDIATE;"
    print -r -- "UPDATE theme SET last_indexed_sha = $(quote "$head") WHERE id = $id;"
    print -r -- "DELETE FROM theme_file WHERE theme_id = $id;"
    while IFS= read -r p; do
      print -r -- "INSERT OR IGNORE INTO theme_file(theme_id, path) VALUES ($id, $(quote "$p"));"
    done < $tmp/candidates.txt
    node_sync_sql $tmp/seed-parse.txt
    theme_node_sql "$id"
    print -r -- "COMMIT;"
  } > $tmp/seed.sql
  if ! sqlite3 -cmd '.timeout 5000' -bail "$db" < $tmp/seed.sql; then
    sql "DELETE FROM theme WHERE id = $id AND NOT EXISTS (SELECT 1 FROM theme_file WHERE theme_id = $id);"
    die "seed failed for $name/$slug"
  fi

  local files syms
  files=$(sql "SELECT count(*) FROM theme_file WHERE theme_id = $id") || die "could not count theme files"
  syms=$(sql "SELECT count(*) FROM theme_node WHERE theme_id = $id") || die "could not count theme symbols"
  print "seeded $name/$slug: $files files, $syms symbols at ${head[1,9]}"
}

cmd_status() {
  local slug=${1:-}
  [[ -f $db ]] || die "no such db: $db"

  local where="t.repo = $(quote "$name")"
  [[ -n $slug ]] && where="$where AND t.slug = $(quote "$slug")"
  sql -separator $'\t' \
    "SELECT t.id, t.slug, COALESCE(t.last_indexed_sha, '') FROM theme t WHERE $where ORDER BY t.slug" \
    > $tmp/themes.tsv || die "could not read themes from $db"
  [[ -z $slug || -s $tmp/themes.tsv ]] || die "no theme $name/$slug in $db — seed it first"
  sql -separator $'\t' \
    "SELECT f.theme_id, f.path FROM theme_file f JOIN theme t ON t.id = f.theme_id WHERE $where" \
    > $tmp/all-theme-files.tsv || die "could not read theme files from $db"

  cut -f2 $tmp/all-theme-files.tsv | sort -u > $tmp/all-paths.txt
  untracked_among $tmp/all-paths.txt

  local incomplete=0
  graph_incomplete && incomplete=1
  local symbols
  symbols=$(sql "SELECT count(*) FROM node WHERE repo = $(quote "$name")") \
    || die "could not read node rows from $db"
  (( symbols )) || incomplete=1

  printf 'repo\tslug\tstate\tfiles\tchanged\tlast_indexed_sha\treason\n'

  local id sl sha state reason files changed verdict
  while IFS=$'\t' read -r id sl sha; do
    files=$(awk -F'\t' -v tid="$id" '$1 == tid { print $2 > OUT; n++ } END { print n + 0 }' \
      OUT=$tmp/theme-files.txt $tmp/all-theme-files.tsv)
    [[ -f $tmp/theme-files.txt ]] || : > $tmp/theme-files.txt
    changed=0 state=stale reason=""
    verdict=$(changed_files "$sha" $tmp/theme-files.txt $tmp/changed.txt)
    case $verdict in
      never-indexed) reason=never-indexed ;;
      unknown-sha)   reason=unknown-sha ;;
      diff-failed)   reason=diff-failed ;;
      *)
        changed=$(count_lines $tmp/changed.txt)
        if (( changed > 0 )); then reason=changed-files
        elif (( files == 0 )); then reason=no-files
        else state=fresh; fi
        ;;
    esac
    if (( incomplete )) && [[ $state == fresh ]]; then state=stale reason=graph-incomplete; fi
    printf '%s\t%s\t%s\t%d\t%d\t%s\t%s\n' "$name" "$sl" "$state" "$files" "$changed" "$sha" "$reason"
    rm -f $tmp/theme-files.txt
  done < $tmp/themes.tsv
}

cmd_reseed() {
  local slug=${1:-}
  [[ -n $slug ]] || usage
  [[ -f $db ]] || die "no such db: $db"
  refuse_linked_worktree "$main_worktree"
  health_table_present || die "graph_health is missing from $db — run bin/index.sh to create it"

  local id
  id=$(sql "SELECT id FROM theme WHERE repo = $(quote "$name") AND slug = $(quote "$slug")") \
    || die "could not read themes from $db"
  [[ -n $id ]] || die "no theme $name/$slug in $db — seed it first"

  sql "SELECT path FROM theme_file WHERE theme_id = $id" > $tmp/theme-files.txt \
    || die "could not read theme files from $db"
  [[ -s $tmp/theme-files.txt ]] \
    || die "$name/$slug covers no files — an interrupted seed left it half-written; seed it again"
  ensure_scope
  untracked_among $tmp/theme-files.txt

  local sha
  sha=$(sql "SELECT COALESCE(last_indexed_sha, '') FROM theme WHERE id = $id") \
    || die "could not read the stamp for $name/$slug"
  local verdict
  verdict=$(changed_files "$sha" $tmp/theme-files.txt $tmp/changed.txt)
  if [[ $verdict != computed ]]; then
    cp $tmp/theme-files.txt $tmp/changed.txt
  fi
  intersect $tmp/scope.txt $tmp/changed.txt > $tmp/parsable.txt

  : > $tmp/reparse.txt
  : > $tmp/vanished.txt
  local f
  while IFS= read -r f; do
    [[ -f $repo/$f ]] && print -r -- "$f" >> $tmp/reparse.txt
  done < $tmp/parsable.txt
  while IFS= read -r f; do
    [[ -f $repo/$f ]] || print -r -- "$f" >> $tmp/vanished.txt
  done < $tmp/changed.txt
  cat $tmp/reparse.txt $tmp/vanished.txt > $tmp/clear.txt

  refuse_unread_stamp "$slug" $tmp/theme-files.txt

  local tracked scoped n gone
  tracked=$(count_lines $tmp/theme-files.txt)
  scoped=$(intersect $tmp/scope.txt $tmp/theme-files.txt | wc -l | tr -d ' ')
  n=$(count_lines $tmp/reparse.txt)
  gone=$(count_lines $tmp/vanished.txt)
  local -a reparse=()

  if (( n > 0 )); then
    reparse=( ${(f)"$(cat $tmp/reparse.txt)"} )
    parse_into_graph_nodes "${reparse[@]}"
  else
    : > $tmp/graph-nodes.tsv
  fi

  sql -separator $'\t' "SELECT path, name FROM node WHERE repo = $(quote "$name")" > $tmp/cited.tsv \
    || die "could not read node rows from $db"
  awk -F'\t' 'NR == FNR { r[$0] = 1; next } ($1 in r) { print $2 }' $tmp/clear.txt $tmp/cited.tsv \
    > $tmp/cited-before.txt
  cut -f1 $tmp/graph-nodes.tsv > $tmp/declared-now.txt
  subtract $tmp/declared-now.txt $tmp/cited-before.txt | sort -u > $tmp/dropped.txt

  {
    print -r -- "BEGIN IMMEDIATE;"
    node_sync_sql $tmp/clear.txt
    theme_node_sql "$id"
    print -r -- "UPDATE theme SET last_indexed_sha = $(quote "$head") WHERE id = $id;"
    local dropped_sym
    while IFS= read -r dropped_sym; do
      print -r -- "INSERT OR IGNORE INTO graph_health(repo, slug, symbol) VALUES ($(quote "$name"), $(quote "$slug"), $(quote "$dropped_sym"));"
    done < $tmp/dropped.txt
    print -r -- "COMMIT;"
  } > $tmp/reseed.sql
  sqlite3 -cmd '.timeout 5000' -bail "$db" < $tmp/reseed.sql || die "reseed failed for $name/$slug"

  if [[ -s $tmp/dropped.txt ]]; then
    print -u2 "theme.sh: dropped $(count_lines $tmp/dropped.txt) symbol(s) whose cited declaration is gone: $(paste -sd' ' - < $tmp/dropped.txt)"
    print -u2 "theme.sh: the reseed committed — exit 3 flags the graph, it does not mean this run failed"
    print -u2 "theme.sh: every theme in $name reads graph-incomplete until bin/index.sh rebuilds the graph"
  fi

  print "reparsed $n of $scoped files in indexer scope ($tracked tracked)"
  if (( n > 0 )); then
    print -rl -- "${reparse[@]}"
  fi
  if [[ -s $tmp/dropped.txt ]]; then
    return 3
  fi
  return 0
}

cmd=${1:-}
case $cmd in
  seed|status|reseed) shift ;;
  *) usage ;;
esac

db=${1:-}; repo=${2:-}
[[ -n $db && -n $repo ]] || usage
shift 2

resolve_repo

tmp=$(mktemp -d "${TMPDIR:-/tmp}/theme.XXXXXXXX") \
  || die "could not create a temp dir under ${TMPDIR:-/tmp}"
tmp=${tmp:A}
cleanup() { rm -rf "$tmp" }
trap cleanup EXIT
trap 'cleanup; trap - INT;  kill -INT  $$' INT
trap 'cleanup; trap - TERM; kill -TERM $$' TERM
trap 'exit 129' HUP

cmd_$cmd "$@"
