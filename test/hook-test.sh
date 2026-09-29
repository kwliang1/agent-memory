#!/bin/zsh
# The three hooks, end to end, through the JSON they are actually handed.
#
# A hook that fails must fail SILENTLY and exit 0 -- anything else lands in the
# session. So most of what is asserted here is the absence of output, which is easy to
# get for the wrong reason: the happy-path cases exist to prove the suite can tell the
# difference.
set -uo pipefail
here=${0:A:h}
repo=${here:h}
db=${1:-$repo/index/graph.db}
target=${2:-/Users/kevin/RubymineProjects/treasury}
[ -f "$db" ] || { print -u2 "no db: $db — run bin/index.sh first"; exit 1 }
[ -d "$target" ] || { print -u2 "no repo to resolve against: $target"; exit 1 }

pass=0; fail=0
die() { print -u2 "hook-test: fixture failure: $1"; exit 1 }
check() {
  local what=$1 want=$2 got=$3
  if [[ $want == "$got" ]]; then print "ok    $what"; pass=$((pass+1))
  else print "FAIL  $what"; print "        want: $want"; print "        got:  $got"; fail=$((fail+1)); fi
}

sess=hooktest-$$
scratch=${TMPDIR:-/tmp}/memory-graph-$sess
cleanup() { rm -f "$scratch"*.seen }
trap cleanup EXIT
trap 'cleanup; trap - INT;  kill -INT  $$' INT
trap 'cleanup; trap - TERM; kill -TERM $$' TERM
fresh() { rm -f "${TMPDIR:-/tmp}/memory-graph-$1.seen" }

start() { MEMORY_GRAPH_DB=$db CLAUDE_PROJECT_DIR=$1 "$repo/hooks/memory-graph.sh" }
ctx()   { jq -r '.hookSpecificOutput.additionalContext // ""' }
retrieve() { MEMORY_GRAPH_DB=$db "$repo/hooks/memory-retrieve.sh" "$1" }

print -r -- "-- SessionStart"
check "names the repo it resolved"        1 "$(start "$target" | ctx | grep -c "^${target:t} —")"
check "carries the right event name"      SessionStart "$(start "$target" | jq -r '.hookSpecificOutput.hookEventName')"
check "stays inside its token ceiling"    yes "$( [[ $(start "$target" | ctx | wc -c) -lt 4000 ]] && print yes || print no )"
# Most of Kevin's sessions run at ~/RubymineProjects, which is not a git repo at all.
# A hook that resolves a repo or gives up is silent for the majority of real sessions.
check "still injects where cwd is no repo" SessionStart "$(start "${target:h}" | jq -r '.hookSpecificOutput.hookEventName')"
check "silent when the db is missing"      0 "$(MEMORY_GRAPH_DB=$scratch-nope.db CLAUDE_PROJECT_DIR=$target "$repo/hooks/memory-graph.sh" | wc -c | tr -d ' ')"

print -r -- "-- UserPromptSubmit"
fresh "$sess-a"
q=$(jq -nc --arg s "$sess-a" --arg c "$target" '{session_id:$s,cwd:$c,prompt:"how does an ach pull get submitted"}')
# Captured once. Every invocation records what it injected, so a second call for the
# same prompt is deduplicated to nothing -- asserting twice against the hook asserts
# against an empty string the second time.
out=$(print -r -- "$q" | retrieve UserPromptSubmit | ctx)
check "surfaces the concept's own file"   yes "$(print -r -- "$out" | grep -q 'app/models/ach_pull.rb' && print yes || print no)"
check "cites a line number with it"       yes "$(print -r -- "$out" | grep -qE 'app/models/ach_pull\.rb:[0-9]+' && print yes || print no)"
# The session already has these concepts; repeating them is spend for nothing.
check "the same prompt again injects nothing" 0 "$(print -r -- "$q" | retrieve UserPromptSubmit | wc -c | tr -d ' ')"
n=$(jq -nc --arg s "$sess-a" --arg c "$target" '{session_id:$s,cwd:$c,prompt:"where do we validate an external wire account"}')
check "a new subject still injects"       yes "$(print -r -- "$n" | retrieve UserPromptSubmit | ctx | grep -q 'external_wire_account' && print yes || print no)"

print -r -- "-- PostToolUse"
fresh "$sess-b"
r=$(jq -nc --arg s "$sess-b" --arg c "$target" --arg body "$(head -30 "$target/app/models/ach_pull.rb" 2>/dev/null)" \
     '{session_id:$s,cwd:$c,tool_name:"Read",tool_input:{file_path:"app/models/ach_pull.rb"},tool_response:$body}')
pt=$(print -r -- "$r" | retrieve PostToolUse | ctx)
check "a read resolves through its path"  yes "$(print -r -- "$pt" | grep -q 'named here: AchPull' && print yes || print no)"
check "and gives the file it declares"    yes "$(print -r -- "$pt" | grep -qE 'app/models/ach_pull\.rb:[0-9]+' && print yes || print no)"
fresh "$sess-c"
# A prompt is deliberate, a tool result is not: at tier 1 this injects three unrelated
# concepts off tokens like "metadata" and "using".
noise=$(jq -nc --arg s "$sess-c" --arg c "$target" \
  '{session_id:$s,cwd:$c,tool_name:"Bash",tool_response:"Fetching gem metadata... Using rake 13.2.1 Resolving dependencies Bundle complete!"}')
check "build chatter injects nothing"     0 "$(print -r -- "$noise" | retrieve PostToolUse | wc -c | tr -d ' ')"

print -r -- "-- cost over a session"
# Claude Code's Read tool always sends file_path ABSOLUTE, so this is the branch that
# actually runs. Every other fixture here uses a repo-relative path.
fresh "$sess-abs"
absr=$(jq -nc --arg s "$sess-abs" --arg c "$target" --arg p "$target/app/models/ach_pull.rb" \
         '{session_id:$s,cwd:$c,tool_name:"Read",tool_input:{file_path:$p},tool_response:"class AchPull; end"}')
absout=$(print -r -- "$absr" | retrieve PostToolUse | ctx)
check "an absolute path resolves"          yes "$(print -r -- "$absout" | grep -q 'app/models/ach_pull.rb:' && print yes || print no)"
# /Users/... put `users` in the token set, which matched the concept `user` and
# injected User, Users::OauthService and Role into a question about an ACH pull.
check "and its directories match no concept" no "$(print -r -- "$absout" | grep -qE '^(user|treasury_prime)$' && print yes || print no)"
# The same read again: every symbol is already in the session.
check "the same read again injects nothing" 0 "$(print -r -- "$absr" | retrieve PostToolUse | wc -c | tr -d ' ')"

# Injection is front-loaded and the taper is not a bound. Past the budget a tool
# result stops earning its tokens; a deliberate prompt never does.
fresh "$sess-cap"
capfile=${TMPDIR:-/tmp}/memory-graph-$sess-cap.seen
printf 'Filler%04d\n' {1..400} > "$capfile"
capr=$(jq -nc --arg s "$sess-cap" --arg c "$target" --arg p "$target/app/models/ach_pull.rb" \
         '{session_id:$s,cwd:$c,tool_name:"Read",tool_input:{file_path:$p},tool_response:"class AchPull; end"}')
check "past the budget a tool result injects nothing" 0 "$(print -r -- "$capr" | retrieve PostToolUse | wc -c | tr -d ' ')"
capq=$(jq -nc --arg s "$sess-cap" --arg c "$target" '{session_id:$s,cwd:$c,prompt:"how does an ach pull get submitted"}')
check "but a prompt is never capped"       yes "$(print -r -- "$capq" | retrieve UserPromptSubmit | ctx | grep -q 'ach_pull' && print yes || print no)"


print -r -- "-- more than one repo in the graph"
# A second repo with symbols but no concepts. Skipping it told a session working
# there nothing at all, while a symbol or a path in that repo already resolves.
two=$scratch-two.db
cp "$db" "$two" || die "copy db"
sqlite3 "$two" "INSERT OR REPLACE INTO node(repo, name, path, line) VALUES ('otherrepo', 'Thing', 'app/thing.rb', 1), ('otherrepo', 'AchPull', 'app/models/ach_pull.rb', 9);
                INSERT OR REPLACE INTO graph_stamp(repo, head_sha) VALUES ('otherrepo', 'abc1234');" \
  || die "seed second repo"
both=$(MEMORY_GRAPH_DB=$two CLAUDE_PROJECT_DIR=${target:h} "$repo/hooks/memory-graph.sh" | ctx)
check "both repos are named"              yes "$(print -r -- "$both" | grep -q "^${target:t} —" && print -r -- "$both" | grep -q '^otherrepo —' && print yes || print no)"
check "the one with no concepts says so"  yes "$(print -r -- "$both" | grep -q 'otherrepo — 2 symbols, no concepts seeded yet' && print yes || print no)"
# Two repos and a cwd that names neither: there is no honest way to choose, so the
# retrieval hook must decline rather than pick the bigger one.
fresh "$sess-d"
  # The decoy repo declares the same path, so ANY pick produces output and only
  # declining produces none. Without that, a mutant picking the empty repo passes.
amb=$(jq -nc --arg s "$sess-d" --arg c "${target:h}" '{session_id:$s,cwd:$c,prompt:"what does app/models/ach_pull.rb do"}' \
      | MEMORY_GRAPH_DB=$two "$repo/hooks/memory-retrieve.sh" UserPromptSubmit | wc -c | tr -d ' ')
check "retrieval declines to guess a repo" 0 "$amb"
rm -f "$two"

print -r -- "-- failing safe"
check "an unknown event is refused"       0 "$(jq -nc '{prompt:"x"}' | retrieve Nonsense | wc -c | tr -d ' ')"
check "no event argument is refused"      0 "$(jq -nc '{prompt:"x"}' | MEMORY_GRAPH_DB=$db "$repo/hooks/memory-retrieve.sh" | wc -c | tr -d ' ')"
check "empty stdin is survived"           0 "$(print -n '' | retrieve UserPromptSubmit | wc -c | tr -d ' ')"
check "stdin that is not JSON is survived" 0 "$(print -r -- 'not json at all' | retrieve UserPromptSubmit | wc -c | tr -d ' ')"
check "a cwd that does not exist is survived" SessionStart "$(start /tmp/definitely-not-here-$$ | jq -r '.hookSpecificOutput.hookEventName')"

print ""
print "$pass passed, $fail failed"
(( fail == 0 ))
