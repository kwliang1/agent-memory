#!/bin/zsh
# SessionStart: tell the session what this repo's code graph can answer, and keep the
# graph current without making every session pay for it.
#
# Scope comes from `git worktree list --porcelain`, not `rev-parse --show-toplevel`:
# --show-toplevel answers with the WORKTREE, and treasury's 47 worktrees live under four
# different parent directories, so no path heuristic recovers the repo.
#
# The cwd is often not a repo at all. 20 of the 35 gradeable rows in baseline/ ran at
# ~/RubymineProjects, where rev-parse exits 128 -- so a hook that resolves a repo or
# gives up is silent for most real sessions. With no repo we name every indexed repo
# instead and let the prompt pick.
set -u
command -v jq      >/dev/null 2>&1 || exit 0
command -v sqlite3 >/dev/null 2>&1 || exit 0
exec 2>/dev/null

here=${0:A:h}
root=${here:h}
db=${MEMORY_GRAPH_DB:-$root/index/graph.db}
[ -f "$db" ] || exit 0

cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
cwd="${cwd%/}"
nl=$'\n'

g() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR git "$@" }

indexed() { sqlite3 -cmd '.timeout 2000' "$db" "SELECT repo FROM graph_stamp ORDER BY repo" }

# Rebuild at most one at a time. Twenty-eight sessions can start together here, and
# while the load is now a single transaction -- so a concurrent reader can no longer see
# an empty graph -- twenty-eight reparses of the same commit is still twenty-eight
# reparses. mkdir is the atomic primitive available: macOS ships no flock.
rebuild() {
  local repo_path=$1 lock=$db.lock
  if ! mkdir "$lock" 2>/dev/null; then
    # A session killed mid-rebuild would otherwise wedge every later one forever.
    local age=$(( $(date +%s) - $(stat -f %m "$lock" 2>/dev/null || echo 0) ))
    (( age > 300 )) || return 2
    rm -f "$lock/owner" 2>/dev/null
    rmdir "$lock" 2>/dev/null && mkdir "$lock" 2>/dev/null || return 2
  fi
  print -r -- $$ > "$lock/owner" 2>/dev/null
  "$root/bin/index.sh" "$repo_path" "$db" >/dev/null 2>&1
  local rc=$?
  # Only remove the lock if it is still ours. Unconditional rmdir deleted the lock of
  # whoever stole it, turning a two-way steal into a three-way race.
  if [ "$(cat "$lock/owner" 2>/dev/null)" = "$$" ]; then
    rm -f "$lock/owner" 2>/dev/null
    rmdir "$lock" 2>/dev/null
  fi
  return $rc
}

repo=""; stale=""
main=$(g -C "$cwd" worktree list --porcelain 2>/dev/null | sed -n '1s|^worktree ||p')
if [ -n "$main" ]; then
  repo=${main:t}
  head=$(g -C "$main" rev-parse --verify 'HEAD^{commit}' 2>/dev/null)
  stamp=$(sqlite3 -cmd '.timeout 2000' "$db" \
    "SELECT head_sha FROM graph_stamp WHERE repo = '${repo//\'/\'\'}'")
  if [ -z "$stamp" ]; then
    # Never indexed. A repo nobody has indexed is not this hook's business to index.
    [ -n "$(sqlite3 -cmd '.timeout 2000' "$db" \
        "SELECT 1 FROM node WHERE repo = '${repo//\'/\'\'}' LIMIT 1")" ] || repo=""
  elif [ -n "$head" ] && [ "$head" != "$stamp" ]; then
    rebuild "$main"
    case $? in
      0) ;;
      2) stale="another session is rebuilding the graph; it was built at ${stamp[1,9]} and $repo is now at ${head[1,9]}" ;;
      *) stale="the graph was built at ${stamp[1,9]} and $repo is now at ${head[1,9]}. Run bin/index.sh to refresh" ;;
    esac
  fi
fi

repos=()
if [ -n "$repo" ]; then
  repos=("$repo")
else
  repos=(${(f)"$(indexed)"})
fi
(( ${#repos} )) || exit 0

out=""
for r in $repos; do
  [[ "$r" =~ '^[A-Za-z0-9._-]+$' ]] || continue
  n=$(sqlite3 -cmd '.timeout 2000' "$db" "SELECT count(*) FROM node WHERE repo = '${r//\'/\'\'}'")
  [[ "$n" =~ '^[0-9]+$' ]] && (( n > 0 )) || continue
  names=$(sqlite3 -cmd '.timeout 2000' "$db" \
    "SELECT group_concat(slug, ', ') FROM (SELECT slug FROM theme WHERE repo = '${r//\'/\'\'}' ORDER BY slug)")
  # theme rows are seeded by hand and a fresh db has none; the reviewed name list is
  # the same list, and it is in git.
  [ -n "$names" ] || names=$(awk -F'\t' 'NR>1{printf "%s%s", sep, $1; sep=", "}' \
    "$root/seeds/$r-concepts.tsv" 2>/dev/null)
# A repo with no concepts seeded yet is still worth naming. Skipping it told a
# session working in that repo nothing at all, while retrieval there already
# works: a symbol or a path named in a prompt resolves straight out of the graph
# without a concept to go through.
if [ -n "$names" ]; then
  out+="$r — $n symbols. Concepts: $names$nl$nl"
else
  out+="$r — $n symbols, no concepts seeded yet. Naming a symbol or a path still resolves.$nl$nl"
fi
done
[ -n "$out" ] || exit 0

pre="Code graph available. Ask about this code in plain language — the concepts a prompt names are resolved to real symbols and injected with file:line, so you do not need to grep for an entry point first.$nl$nl"
[ -n "$stale" ] && pre+="Stale: $stale.$nl$nl"

printf '%s' "$pre$out" | jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}'
