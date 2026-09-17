# Sourced by bin/theme.sh and bin/load-concepts.sh, which set $prog, $db and $repo first.
# resolve_repo then sets $main_worktree, $name, $own_toplevel and $head.

die() {
  print -u2 "$prog: $1"
  exit 1
}

quote() { print -r -- "'${1//\'/''}'" }

git_repo() {
  env -u GIT_DIR -u GIT_WORK_TREE git -C "$repo" -c core.quotePath=false -c diff.renames=false "$@"
}

sql() { sqlite3 -cmd '.timeout 5000' "$db" "$@" }

count_lines() { wc -l < "$1" | tr -d ' ' }

graph_db_present() {
  local present
  present=$(sql "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'node'") \
    || die "could not read $db"
  (( present ))
}

health_table_present() {
  local present
  present=$(sql "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'graph_health'") \
    || die "could not read $db"
  (( present )) || return 1
  local shaped
  shaped=$(sql "SELECT count(*) FROM pragma_table_info('graph_health') WHERE name = 'symbol'") \
    || die "could not read graph_health from $db"
  (( shaped )) && return 0
  die "graph_health in $db is not the shape theme.sh writes (expected column: symbol) — check bin/schema.sql"
}

refuse_linked_worktree() {
  local main_worktree=$1
  [[ ${main_worktree:A} == ${own_toplevel:A} ]] && return 0
  print -u2 "$prog: refusing: $repo is a linked worktree of $main_worktree"
  die "the graph is written under the main checkout's name, and this worktree's HEAD dies with its branch — run this there"
}

resolve_repo() {
  [[ -e $repo ]] || die "no such path: $repo"
  git_repo rev-parse --git-dir > /dev/null 2>&1 || die "not a git repo: $repo"
  main_worktree=$(git_repo worktree list --porcelain | sed -n '1s|^worktree ||p')
  [[ -n $main_worktree ]] || die "could not resolve the main worktree for $repo"
  name=${main_worktree:t}
  [[ -n $name && $name != *[^A-Za-z0-9._-]* ]] || die "unsafe repo name: $name"
  own_toplevel=$(git_repo rev-parse --show-toplevel) || die "could not resolve the toplevel of $repo"
  [[ ${repo:A} == ${own_toplevel:A} ]] \
    || die "$repo is not a worktree root — git reports diffs relative to $own_toplevel, so a theme seeded here could never go stale"
  head=$(git_repo rev-parse --verify HEAD^{commit} 2>/dev/null) \
    || die "$repo has no commits — nothing to stamp a theme against"
}
