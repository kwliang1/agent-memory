#!/bin/zsh
# bin/reindex.sh against a throwaway origin, clone and graph: it follows origin/main,
# builds outside the shared checkout, and the session-start hook does not undo it.
set -uo pipefail
here=${0:A:h}
root=${here:h}

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0
check() {
  local what=$1 want=$2 got=$3
  if [[ $want == "$got" ]]; then print "ok    $what"; pass=$((pass+1))
  else print "FAIL  $what"; print "        want: $want"; print "        got:  $got"; fail=$((fail+1)); fi
}
abort() { print -u2 "fixture failure: $1"; exit 1 }
tg() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
         git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c init.defaultBranch=main "$@" }

db=$tmp/graph.db
proj=$tmp/roots/rtest
other=$tmp/other
trees=$tmp/trees
log=$tmp/reindex.log
run() { MEMORY_SEARCH_ROOTS=$tmp/roots MEMORY_INDEX_TREES=$trees "$root/bin/reindex.sh" "$db" >> $log 2>&1 }
stamp() { sqlite3 "$db" "SELECT head_sha FROM graph_stamp WHERE repo = 'rtest'" }
has() { sqlite3 "$db" "SELECT count(*) FROM node WHERE repo = 'rtest' AND name = '$1'" }

tg init -q --bare $tmp/origin.git || abort "bare origin"
tg clone -q $tmp/origin.git $proj 2>/dev/null || abort "clone"
mkdir -p $proj/app/models && print 'class Alpha; end' > $proj/app/models/alpha.rb
tg -C $proj add -A && tg -C $proj commit -qm one && tg -C $proj push -q origin main 2>/dev/null || abort "first push"
"$root/bin/index.sh" $proj $db >/dev/null 2>&1 || abort "first index"
first=$(tg -C $proj rev-parse HEAD)

tg clone -q $tmp/origin.git $other 2>/dev/null || abort "second clone"
print 'class Beta; end' > $other/app/models/beta.rb
tg -C $other add -A && tg -C $other commit -qm two && tg -C $other push -q origin main 2>/dev/null || abort "second push"
tg -C $proj fetch -q origin || abort "fetch"
tip=$(tg -C $proj rev-parse origin/main)
print 'scratch' > $proj/uncommitted.txt

print -r -- "-- following origin/main"
run
check "the stamp moves to origin/main"           $tip  "$(stamp)"
check "and the new symbol is in the graph"       1     "$(has Beta)"
check "the shared checkout did not move"         $first "$(tg -C $proj rev-parse HEAD)"
check "and its uncommitted work is untouched"    scratch "$(cat $proj/uncommitted.txt)"
check "it built in its own worktree"             $tip  "$(tg -C $trees/rtest rev-parse HEAD)"
: > $log
run
check "nothing to do is silent"                  0     "$(wc -c < $log | tr -d ' ')"

print -r -- "-- the session-start hook"
MEMORY_GRAPH_DB=$db CLAUDE_PROJECT_DIR=$proj "$root/hooks/memory-graph.sh" >/dev/null
check "a checkout behind the graph does not rebuild it" $tip "$(stamp)"

print -r -- "-- a held lock"
print 'class Gamma; end' > $other/app/models/gamma.rb
tg -C $other add -A && tg -C $other commit -qm three && tg -C $other push -q origin main 2>/dev/null || abort "third push"
tg -C $proj fetch -q origin || abort "second fetch"
mkdir $db.lock && print 999999 > $db.lock/owner
run
check "a live lock is respected"                 $tip  "$(stamp)"
check "and left in place"                        999999 "$(cat $db.lock/owner)"
touch -t 202001010000 $db.lock
run
check "a lock older than five minutes is taken"  "$(tg -C $proj rev-parse origin/main)" "$(stamp)"
check "and released after"                       no    "$( [[ -d $db.lock ]] && print yes || print no )"

print -r -- "-- a checkout with its own commits"
print 'class Local; end' > $proj/app/models/local.rb
tg -C $proj add app/models/local.rb && tg -C $proj commit -qm local || abort "local commit"
MEMORY_GRAPH_DB=$db CLAUDE_PROJECT_DIR=$proj "$root/hooks/memory-graph.sh" >/dev/null
check "a graph at origin/main is not rebuilt from a diverged HEAD" "$(tg -C $proj rev-parse origin/main)" "$(stamp)"

print -r -- "-- a graph ahead of the checkout but behind origin/main"
print 'class Epsilon; end' > $other/app/models/epsilon.rb
tg -C $other add -A && tg -C $other commit -qm five && tg -C $other push -q origin main 2>/dev/null || abort "fifth push"
tg -C $proj fetch -q origin || abort "fifth fetch"
was=$(stamp)
tg -C $proj reset -q --hard $first || abort "reset behind"
MEMORY_GRAPH_DB=$db CLAUDE_PROJECT_DIR=$proj "$root/hooks/memory-graph.sh" >/dev/null
check "is not rebuilt from the checkout"         $was "$(stamp)"

print -r -- "-- a session-start rebuild"
tg -C $proj reset -q --hard origin/main && print 'class Zeta; end' > $proj/app/models/zeta.rb \
  && tg -C $proj add -A && tg -C $proj commit -qm ahead || abort "ahead commit"
out=$(MEMORY_GRAPH_DB=$db CLAUDE_PROJECT_DIR=$proj "$root/hooks/memory-graph.sh")
check "rebuilds a checkout ahead of the graph"   "$(tg -C $proj rev-parse HEAD)" "$(stamp)"
check "and still prints only its JSON"           SessionStart "$(print -r -- "$out" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)"

print -r -- "-- a deleted index tree"
rm -rf $trees/rtest
print 'class Delta; end' > $other/app/models/delta.rb
tg -C $other add -A && tg -C $other commit -qm four && tg -C $other push -q origin main 2>/dev/null || abort "fourth push"
tg -C $proj fetch -q origin || abort "third fetch"
run
check "is recreated and the graph follows"       "$(tg -C $proj rev-parse origin/main)" "$(stamp)"

print -r -- "-- an index tree orphaned by a re-clone"
rm -rf $trees/rtest/.git && print 'gitdir: /nonexistent' > $trees/rtest/.git
print 'class Eta; end' > $other/app/models/eta.rb
tg -C $other add -A && tg -C $other commit -qm six && tg -C $other push -q origin main 2>/dev/null || abort "sixth push"
tg -C $proj fetch -q origin || abort "sixth fetch"
run
check "is moved aside and re-added"              "$(tg -C $proj rev-parse origin/main)" "$(stamp)"
check "nothing was deleted"                      1 "$(ls -d $trees/rtest.broken.* 2>/dev/null | wc -l | tr -d ' ')"

print -r -- "-- trees pointed at the shared checkout"
before=$(tg -C $proj rev-parse HEAD)
sqlite3 "$db" "UPDATE graph_stamp SET head_sha = 'stale' WHERE repo = 'rtest'"
MEMORY_SEARCH_ROOTS=$tmp/roots MEMORY_INDEX_TREES=$tmp/roots "$root/bin/reindex.sh" "$db" >> $log 2>&1
check "the shared checkout is not moved"         $before "$(tg -C $proj rev-parse HEAD)"
check "nor cleaned"                              scratch "$(cat $proj/uncommitted.txt 2>/dev/null)"

print -r -- "-- a failure says why"
: > $log
sqlite3 "$db" "UPDATE graph_stamp SET head_sha = 'stale' WHERE repo = 'rtest'"
print 'scratch' > $trees/rtest/app/models/dirty.rb
run
check "a dirty index tree is cleaned and indexed" "$(tg -C $proj rev-parse origin/main)" "$(stamp)"
check "and the stray file is gone"               no "$( [[ -e $trees/rtest/app/models/dirty.rb ]] && print yes || print no )"
: > $log
tg -C $other rm -rq app && tg -C $other commit -qm empty && tg -C $other push -q origin main 2>/dev/null || abort "empty push"
tg -C $proj fetch -q origin || abort "fourth fetch"
run
check "an index failure is logged"               1 "$(grep -c 'index.sh failed' $log)"
check "with index.sh's own reason"               1 "$(grep -c 'no ruby files' $log)"

print -r -- "-- a repo with no checkout"
: > $log
sqlite3 "$db" "INSERT OR REPLACE INTO graph_stamp(repo, head_sha) VALUES ('gone', 'x')"
run
check "is named in the log and skipped"          1     "$(grep -c '^.* gone: no checkout under' $log)"
sqlite3 "$db" "DELETE FROM graph_stamp WHERE repo = 'gone'"

print -r -- "-- index.sh still refuses other worktrees"
tg -C $proj worktree add -q --detach $tmp/side $first 2>/dev/null || abort "side worktree"
MEMORY_INDEX_CANONICAL=1 "$root/bin/index.sh" $tmp/side $db >/dev/null 2>&1
check "a worktree off origin/main is refused, flag or not" 1 "$?"
"$root/bin/index.sh" $trees/rtest $db >/dev/null 2>&1
check "the index tree without the flag is refused" 1 "$?"
print 'scratch' > $trees/rtest/dirty.rb
MEMORY_INDEX_CANONICAL=1 "$root/bin/index.sh" $trees/rtest $db 2> $tmp/err >/dev/null
check "a dirty index tree is refused, and says so" 1 "$(grep -c 'not a clean worktree' $tmp/err)"

print ""
print "$pass passed, $fail failed"
(( fail == 0 ))
