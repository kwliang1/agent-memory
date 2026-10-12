# Sourced by hooks/memory-graph.sh and bin/reindex.sh, so the two rebuild under one lock.
#
# Rebuild at most one at a time. Twenty-eight sessions can start together here, and
# while the load is now a single transaction -- so a concurrent reader can no longer see
# an empty graph -- twenty-eight reparses of the same commit is still twenty-eight
# reparses. mkdir is the atomic primitive available: macOS ships no flock.
#
# Usage: locked_run <db> <command...>. Returns 2 if someone else holds the lock, else the
# command's status. Its stdout is discarded -- the SessionStart hook's stdout is its JSON --
# and its stderr is left to the caller.
locked_run() {
  local db=$1 lock=$1.lock; shift
  if ! mkdir "$lock" 2>/dev/null; then
    # A process killed mid-rebuild would otherwise wedge every later one forever.
    local age=$(( $(date +%s) - $(stat -f %m "$lock" 2>/dev/null || echo 0) ))
    (( age > 300 )) || return 2
    rm -f "$lock/owner" 2>/dev/null
    rmdir "$lock" 2>/dev/null && mkdir "$lock" 2>/dev/null || return 2
  fi
  print -r -- $$ > "$lock/owner" 2>/dev/null
  "$@" >/dev/null
  local rc=$?
  # Only remove the lock if it is still ours. Unconditional rmdir deleted the lock of
  # whoever stole it, turning a two-way steal into a three-way race.
  if [ "$(cat "$lock/owner" 2>/dev/null)" = "$$" ]; then
    rm -f "$lock/owner" 2>/dev/null
    rmdir "$lock" 2>/dev/null
  fi
  return $rc
}
