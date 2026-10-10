#!/bin/zsh
# Rebuild each indexed repo's graph from origin/main when it has moved. Run by launchd.
# Usage: reindex.sh [db-path]
#
# It reads origin/main as this machine last fetched it and does not fetch: sessions fetch
# all day, and a fetch from launchd would raise a 1Password SSH prompt every interval.
# Set MEMORY_REINDEX_FETCH=1 to fetch anyway.
#
# It builds in its own worktree under $MEMORY_INDEX_TREES, never in the shared checkout,
# which other sessions have uncommitted work in.
set -uo pipefail
here=${0:A:h}
db=${1:-${here:h}/index/graph.db}
trees=${MEMORY_INDEX_TREES:-$HOME/.agent-memory-index}
roots=(${(s.:.)${MEMORY_SEARCH_ROOTS:-$HOME/RubymineProjects:$HOME}})
[ -f "$db" ] || exit 0

source "$here/graph-lock.zsh"
g() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR git "$@" }
log() { print -r -- "$(date -u +%FT%TZ) $*" }

# The tree is only ever forced and cleaned if it is a LINKED worktree of this repo rooted
# exactly at $tree -- never the shared checkout, whatever MEMORY_INDEX_TREES says. Anything
# else at that path is moved aside, not deleted, and the tree re-added; add -f takes over a
# stale registration for this path alone, where a repo-wide prune would also drop other
# sessions' worktrees that are briefly missing.
sync_and_index() {
  local main=$1 tree=$2 tip=$3
  [ "${tree:A}" != "${main:A}" ] || return 3
  local common=$(g -C "$main" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  if [ "$(g -C "$tree" rev-parse --show-toplevel 2>/dev/null)" = "${tree:A}" ] \
     && [ "$(g -C "$tree" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" = "$common" ] \
     && [ "$(g -C "$tree" rev-parse --path-format=absolute --git-dir 2>/dev/null)" != "$common" ]; then
    g -C "$tree" checkout -q --detach --force "$tip" && g -C "$tree" clean -fdq || return 3
  else
    [ -e "$tree" ] && { mv "$tree" "$tree.broken.$(date +%s)" || return 3 }
    mkdir -p "${tree:h}" && g -C "$main" worktree add -q -f --detach "$tree" "$tip" || return 3
  fi
  MEMORY_INDEX_CANONICAL=1 "$here/index.sh" "$tree" "$db"
}

for name in ${(f)"$(sqlite3 -cmd '.timeout 2000' "$db" 'SELECT repo FROM graph_stamp ORDER BY repo')"}; do
  [[ "$name" =~ '^[A-Za-z0-9._-]+$' ]] || continue
  main=""
  for r in $roots; do
    [ -d "$r/$name" ] && g -C "$r/$name" rev-parse --git-dir >/dev/null 2>&1 && { main=$r/$name; break }
  done
  [ -n "$main" ] || { log "$name: no checkout under ${(j.:.)roots}"; continue }

  [ "${MEMORY_REINDEX_FETCH:-}" = 1 ] && g -C "$main" fetch -q origin main
  tip=$(g -C "$main" rev-parse --verify 'origin/main^{commit}' 2>/dev/null) \
    || { log "$name: no origin/main"; continue }
  stamp=$(sqlite3 -cmd '.timeout 2000' "$db" "SELECT head_sha FROM graph_stamp WHERE repo = '$name'")
  [ "$tip" = "$stamp" ] && continue

  # The same lock memory-graph.sh takes, held across moving the tree as well as indexing
  # it. A held lock means someone is already rebuilding; the next interval catches up.
  locked_run "$db" sync_and_index "$main" "$trees/$name" "$tip"
  case $? in
    0) log "$name: ${stamp[1,9]:-none} -> ${tip[1,9]}" ;;
    2) log "$name: lock held, skipping" ;;
    3) log "$name: could not put $trees/$name at ${tip[1,9]}" ;;
    *) log "$name: index.sh failed at ${tip[1,9]}" ;;
  esac
done
exit 0
