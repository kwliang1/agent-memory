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
cleanup() { rm -rf "${scratch:?}"{.,-}*(N) }
trap cleanup EXIT
trap 'cleanup; trap - INT;  kill -INT  $$' INT
trap 'cleanup; trap - TERM; kill -TERM $$' TERM
fresh() { rm -f "${TMPDIR:-/tmp}/memory-graph-$1".*(N) }

start() { MEMORY_GRAPH_DB=$db CLAUDE_PROJECT_DIR=$1 "$repo/hooks/memory-graph.sh" }
ctx()   { jq -r '.hookSpecificOutput.additionalContext // ""' }
retrieve() { MEMORY_GRAPH_DB=$db "$repo/hooks/memory-retrieve.sh" "$1" }
up() { jq -nc --arg s "$1" --arg c "$2" --arg p "$3" '{session_id:$s,cwd:$c,prompt:$p}' | retrieve UserPromptSubmit }

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
# This prompt matches far more concepts than the cut keeps. With a prompt that
# matches fewer, excluding before the cut and after it are indistinguishable, and the
# repeat assertion below cannot fail.
q=$(jq -nc --arg s "$sess-a" --arg c "$target" '{session_id:$s,cwd:$c,prompt:"where do we validate an external wire account"}')
# Captured once. Every invocation records what it injected, so a second call for the
# same prompt is deduplicated to nothing -- asserting twice against the hook asserts
# against an empty string the second time.
out=$(print -r -- "$q" | retrieve UserPromptSubmit | ctx)
check "surfaces the concept's own file"   yes "$(print -r -- "$out" | grep -q 'app/models/external_wire_account.rb' && print yes || print no)"
check "cites a line number with it"       yes "$(print -r -- "$out" | grep -qE 'app/models/external_wire_account\.rb:[0-9]+' && print yes || print no)"
# The session already has these concepts; repeating them is spend for nothing.
check "the same prompt again injects nothing" 0 "$(print -r -- "$q" | retrieve UserPromptSubmit | wc -c | tr -d ' ')"
n=$(jq -nc --arg s "$sess-a" --arg c "$target" '{session_id:$s,cwd:$c,prompt:"how does an ach pull get submitted"}')
check "a new subject still injects"       yes "$(print -r -- "$n" | retrieve UserPromptSubmit | ctx | grep -q 'ach_pull' && print yes || print no)"

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
capfile=${TMPDIR:-/tmp}/memory-graph-$sess-cap.${target:t}.seen
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
# Two repos, and neither the cwd nor the prompt names one: there is no honest way to choose, so the
# retrieval hook must decline rather than pick the bigger one.
fresh "$sess-d"
  # The decoy repo declares the same path, so ANY pick produces output and only
  # declining produces none. Without that, a mutant picking the empty repo passes.
amb=$(jq -nc --arg s "$sess-d" --arg c "${target:h}" '{session_id:$s,cwd:$c,prompt:"what does app/models/ach_pull.rb do"}' \
      | MEMORY_GRAPH_DB=$two "$repo/hooks/memory-retrieve.sh" UserPromptSubmit | wc -c | tr -d ' ')
check "retrieval declines to guess a repo" 0 "$amb"
at() { jq -nc --arg s "$2" --arg c "$3" --arg k "$4" --arg f "$5" --arg t "$6" '{session_id:$s,cwd:$c,tool_name:"Read",tool_input:{($k):$f},tool_response:$t}' | MEMORY_GRAPH_DB=$1 "$repo/hooks/memory-retrieve.sh" PostToolUse }
fresh "$sess-mr"
check "the repo named first wins"                  yes "$(db=$two up "$sess-mr" "${target:h}" 'treasury calls otherrepo: what does app/models/ach_pull.rb do' | ctx | grep -q '^ach_pull$' && print yes || print no)"
check "a tool result answers for the bound repo"   no  "$(at $two "$sess-mr" "${target:h}" path "" 'otherrepo/app/models/ach_pull.rb treasury/README.md' | ctx | grep -q 'app/models/ach_pull.rb:9' && print yes || print no)"
check "a tool result does not move the binding"   yes "$(db=$two up "$sess-mr" "${target:h}" 'why is an incoming wire stuck' | ctx | grep -q '^incoming_wire$' && print yes || print no)"
check "a prompt naming the other repo does, and what it injected before is not held against it" \
  yes "$(db=$two up "$sess-mr" "${target:h}" 'over in otherrepo, what does app/models/ach_pull.rb do' | ctx | grep -q 'app/models/ach_pull.rb:9' && print yes || print no)"
check "and it stays moved"                         yes "$(db=$two up "$sess-mr" "${target:h}" 'what does app/thing.rb do' | ctx | grep -q 'app/thing.rb:1' && print yes || print no)"
check "moving back re-injects nothing it already had" 0 "$(db=$two up "$sess-mr" "${target:h}" 'back in treasury, why is an incoming wire stuck' | wc -c | tr -d ' ')"
fresh "$sess-mr2"
check "whichever order the repos are listed in"    0   "$(db=$two up "$sess-mr2" "${target:h}" 'otherrepo calls treasury: why is an outgoing wire stuck' | wc -c | tr -d ' ')"
fresh "$sess-xp"
db=$two up "$sess-xp" "${target:h}" 'over in otherrepo, what is up' > /dev/null
xp=$(at $two "$sess-xp" "${target:h}" file_path "$target/app/models/ach_pull.rb" 'class AchPull' | ctx)
check "a file read in another repo resolves against that repo" yes "$(print -r -- "$xp" | grep -qE 'app/models/ach_pull\.rb:[0-9]+' && ! print -r -- "$xp" | grep -q 'app/models/ach_pull.rb:9$' && print yes || print no)"
check "and leaves the binding where it was"        otherrepo "$(<"${TMPDIR:-/tmp}/memory-graph-$sess-xp.bound")"
check "a file in a repo with no graph injects nothing" 0 "$(at $two "$sess-xp" "${target:h}" file_path "$repo/bin/match.sh" 'see app/thing.rb' | wc -c | tr -d ' ')"
check "a file outside any repo keeps the bound repo" yes "$(at $two "$sess-xp" "${target:h}" file_path "${TMPDIR:-/tmp}/memory-graph-$sess-xp.none/x.rb" 'see app/thing.rb' | ctx | grep -q 'app/thing.rb:1' && print yes || print no)"
fresh "$sess-gp"
db=$two up "$sess-gp" "${target:h}" 'over in otherrepo, what is up' > /dev/null
gp=$(at $two "$sess-gp" "${target:h}" path "$target" 'app/models/ach_pull.rb:3: class AchPull' | ctx)
check "a search path resolves the same way"        yes "$(print -r -- "$gp" | grep -qE 'app/models/ach_pull\.rb:[0-9]+' && ! print -r -- "$gp" | grep -q 'app/models/ach_pull.rb:9$' && print yes || print no)"
fresh "$sess-nb"
at $two "$sess-nb" "${target:h}" file_path "$repo/bin/treasury_thing.rb" 'class TreasuryThing' > /dev/null
check "a path's own repo outranks a repo name inside it" "" "$(cat "${TMPDIR:-/tmp}/memory-graph-$sess-nb.bound" 2>/dev/null)"
fresh "$sess-rc"
check "a repo cwd still answers for a file read in another repo" yes "$(at $db "$sess-rc" "$repo" file_path "$target/app/models/ach_pull.rb" 'class AchPull' | ctx | grep -qE 'app/models/ach_pull\.rb:[0-9]+' && print yes || print no)"
fresh "$sess-ob"
at $two "$sess-ob" "${target:h}" file_path "$target/app/models/ach_pull.rb" 'class AchPull' > /dev/null
check "a file read in an indexed repo binds an unbound session" yes "$(db=$two up "$sess-ob" "${target:h}" 'why is an incoming wire stuck' | ctx | grep -q '^incoming_wire$' && print yes || print no)"
rm -f "$two"

print -r -- "-- the concept a named path belongs to comes first"
# A concept that owns a symbol the text named outright is ranked above one that merely
# matched a token. Only the ORDER changes, which is why set-membership cases cannot
# see it: `wire` has undirected degree 1 and loses to `outgoing_payment` on degree alone,
# but the path named a Wire:: symbol, so it is what the question is about.
fresh "$sess-ord"
ordout=$(jq -nc --arg s "$sess-ord" --arg c "$target" \
           '{session_id:$s,cwd:$c,prompt:"what does lib/wire/validations/format.rb do to an outgoing payment"}' \
         | retrieve UserPromptSubmit | ctx)
ordw=$(print -r -- "$ordout" | grep -n '^wire$' | cut -d: -f1)
ordv=$(print -r -- "$ordout" | grep -n '^outgoing_payment$' | cut -d: -f1)
check "both concepts are present"          yes "$( [[ -n $ordw && -n $ordv ]] && print yes || print no )"
check "the named one is ranked first"      yes "$( [[ -n $ordw && -n $ordv && $ordw -lt $ordv ]] && print yes || print no )"

print -r -- "-- a row with no file is not given one"
# rank.sh's -column output is a DISPLAY format. Parsed positionally, a node the graph
# has an edge to but no declaration for printed its score and hop count as though they
# were a path and a line: "Ghost  1.354:1". Worst possible output for a tool whose
# whole promise is a real file:line. A purpose-built graph, because in treasury such a
# node never ranks high enough to reach the payload -- which is what made the first
# version of this test vacuous.
ph=$scratch-phantom.db
rm -f "$ph"
sqlite3 "$ph" < "$repo/bin/schema.sql" > /dev/null || die "phantom schema"
sqlite3 "$ph" "INSERT INTO node(repo, name, path, line) VALUES ('${target:t}', 'Alpha', 'app/alpha.rb', 3);
               INSERT INTO edge(src, dst, repo, kind) VALUES
                 ('Alpha', 'Ghost', '${target:t}', 'references'),
                 ('Ghost', 'Alpha', '${target:t}', 'references');
               INSERT INTO graph_stamp(repo, head_sha) VALUES ('${target:t}', 'abc1234');" || die "phantom rows"
check "Ghost has no node row"             0 "$(sqlite3 "$ph" "SELECT count(*) FROM node WHERE name = 'Ghost'")"
check "and the ranker returns it first"   1 "$(RANK_FORMAT=tsv "$repo/bin/rank.sh" "$ph" Alpha 2 5 "${target:t}" | grep -c '^Ghost')"
fresh "$sess-ph"
phout=$(jq -nc --arg s "$sess-ph" --arg c "$target" '{session_id:$s,cwd:$c,prompt:"what does app/alpha.rb do"}' \
        | MEMORY_GRAPH_DB=$ph "$repo/hooks/memory-retrieve.sh" UserPromptSubmit | ctx)
check "the real declaration is injected"  yes "$(print -r -- "$phout" | grep -q 'app/alpha.rb:3' && print yes || print no)"
check "and no score is rendered as a path" no "$(print -r -- "$phout" | grep -qE '[0-9]+\.[0-9]+:[0-9]+' && print yes || print no)"
rm -f "$ph"

print -r -- "-- what is not a person asking"
fresh "$sess-env"
check "the bridge envelope alone injects nothing" 0 \
  "$(up "$sess-env" "$target" '<channel source="plugin:discord:discord" chat_id="D1:2" user="Kevin Liang" user_id="U1">hey are you there</channel>' | wc -c | tr -d ' ')"
check "but its body still does"           yes \
  "$(up "$sess-env" "$target" '<channel source="plugin:discord:discord" user="Kevin Liang">why is an outgoing wire stuck</channel>' | ctx | grep -q '^outgoing_wire$' && print yes || print no)"
fresh "$sess-tn"
check "a task notification injects nothing" 0 \
  "$(up "$sess-tn" "$target" '<task-notification><task-id>a1</task-id><summary>Agent "outgoing wire review" finished</summary></task-notification>' | wc -c | tr -d ' ')"
check "a spawn line injects nothing"      0 "$(up "$sess-tn" "$target" '[system] Spawned orbit for: treasury outgoing wire stuck' | wc -c | tr -d ' ')"
fresh "$sess-sp"
sp=$'<hydra-prompt>\nYou are fern, a spawned session. Topic: <request>treasury why is an outgoing wire stuck</request>\n\nYour chat thread chat_id is D1:2. Your session_id is abc. Read your memory files for context and check the balance hold.\n</hydra-prompt>'
spout=$(up "$sess-sp" "$target" "$sp" | ctx)
check "a spawn prompt matches on its topic" yes "$(print -r -- "$spout" | grep -q '^outgoing_wire$' && print yes || print no)"
check "and not on its boilerplate"        no  "$(print -r -- "$spout" | grep -qE '^(user|user_policy|balance_hold)$' && print yes || print no)"
fresh "$sess-sub"
check "a word is not matched inside another" no \
  "$(up "$sess-sub" "$target" 'link to main and check it' | ctx | grep -qE '^(maintenance_tasks_ui|balance_check)$' && print yes || print no)"

fresh "$sess-sys"
check "a relayed system line injects nothing" 0 \
  "$(up "$sess-sys" "$target" $'<channel source="plugin:discord:discord" user="system">\n[system] Spawned orbit for: treasury outgoing wire stuck</channel>' | wc -c | tr -d ' ')"
fresh "$sess-st"
check "a stopped word is not matched inside a longer one" no \
  "$(up "$sess-st" "$target" 'how many users and accounts signed up' | ctx | grep -qE '^(user|account)$' && print yes || print no)"
fresh "$sess-wk"
check "a weak word does not name a concept" no \
  "$(up "$sess-wk" "$target" 'restart the service and resend the request' | ctx | grep -qE '_service$|_request$' && print yes || print no)"
fresh "$sess-rn"
check "the repo's own name names no concept" no \
  "$(up "$sess-rn" "$target" 'in treasury, how does an ach pull get submitted' | ctx | grep -qE '^treasury_(prime|event|app)$' && print yes || print no)"

fresh "$sess-t1"
check "a top symbol's word reaches its concept" yes \
  "$(up "$sess-t1" "$target" 'microdeposit verification failed' | ctx | grep -q '^plaid$' && print yes || print no)"
fresh "$sess-x"
check "a message from another session injects nothing" 0 \
  "$(up "$sess-x" "$target" '<cross-session-message from="uds:/tmp/x.sock">outgoing wire stuck</cross-session-message>' | wc -c | tr -d ' ')"
check "a subagent hand-back injects nothing" 0 \
  "$(up "$sess-x" "$target" '<agent-message from="a1">outgoing wire stuck</agent-message>' | wc -c | tr -d ' ')"
fresh "$sess-sr"
check "a system reminder is not matched" no \
  "$(up "$sess-sr" "$target" $'what now\n<system-reminder>outgoing wire stuck</system-reminder>' | ctx | grep -q '^outgoing_wire$' && print yes || print no)"

fresh "$sess-sw"
check "a concept name inside a longer word is not matched" 0 \
  "$(up "$sess-sw" "$target" 'fundamentally wireless' | wc -c | tr -d ' ')"
fresh "$sess-one"
check "one ordinary word names nothing"   0   "$(up "$sess-one" "$target" 'push it and run the review again' | wc -c | tr -d ' ')"
fresh "$sess-pair"
check "two short words name their concept" yes \
  "$(up "$sess-pair" "$target" 'why is the sub account balance wrong' | ctx | grep -q '^sub_account$' && print yes || print no)"
fresh "$sess-envs"
check "the envelope is stripped, not just stopped" no \
  "$(up "$sess-envs" "$target" '<channel source="x" chat_id="D1" user="Ledger Entry">hey</channel>' | ctx | grep -q '^ledger_entry$' && print yes || print no)"

print -r -- "-- a cwd that is no repo"
fresh "$sess-um"
check "silent until the repo is named"    0 "$(up "$sess-um" "${target:h}" 'why is an outgoing wire stuck' | wc -c | tr -d ' ')"
check "injects once it is"                yes "$(up "$sess-um" "${target:h}" 'in treasury, how does an ach pull get submitted' | ctx | grep -q '^ach_pull$' && print yes || print no)"
check "and stays bound after"             yes "$(up "$sess-um" "${target:h}" 'why is an outgoing wire stuck' | ctx | grep -q '^outgoing_wire$' && print yes || print no)"

fresh "$sess-um2"
check "the repo is named in any case"     yes "$(up "$sess-um2" "${target:h}" 'In Treasury, why is an outgoing wire stuck' | ctx | grep -q '^outgoing_wire$' && print yes || print no)"
fresh "$sess-um3"
check "but not inside another word"       0   "$(up "$sess-um3" "${target:h}" 'treasuryx: why is an outgoing wire stuck' | wc -c | tr -d ' ')"

print -r -- "-- fetched threads and issues"
ptu() { jq -nc --arg s "$1" --arg c "$target" --arg t "$2" --arg cmd "$3" --arg body "$4" \
          '{session_id:$s,cwd:$c,tool_name:$t,tool_input:{command:$cmd},tool_response:$body}' | retrieve PostToolUse }
fresh "$sess-lin"
check "a Linear issue resolves"           yes "$(ptu "$sess-lin" mcp__linear__get_issue '' 'BANK-1: outgoing wire stuck after the external wire account changed' | ctx | grep -q '^outgoing_wire$' && print yes || print no)"
fresh "$sess-gh"
check "gh output resolves"                yes "$(ptu "$sess-gh" Bash 'gh pr view 9060' 'Fix: outgoing wire stuck after the external wire account changed' | ctx | grep -q '^outgoing_wire$' && print yes || print no)"
fresh "$sess-sh"
check "other Bash output does not"        0   "$(ptu "$sess-sh" Bash 'grep -rn foo .' 'outgoing wire stuck after the external wire account changed' | wc -c | tr -d ' ')"

fresh "$sess-gha"
check "gh api output resolves"            yes "$(ptu "$sess-gha" Bash 'cd x && gh api repos/a/b/pulls/1' 'outgoing wire stuck after the external wire account changed' | ctx | grep -q '^outgoing_wire$' && print yes || print no)"
fresh "$sess-ghx"
check "other gh output does not"          0   "$(ptu "$sess-ghx" Bash 'gh auth status' 'outgoing wire stuck after the external wire account changed' | wc -c | tr -d ' ')"
fresh "$sess-ghm"
check "an indented gh in a multi-line command resolves" yes "$(ptu "$sess-ghm" Bash $'cd x\n  gh pr view 1' 'outgoing wire stuck after the external wire account changed' | ctx | grep -q '^outgoing_wire$' && print yes || print no)"

fresh "$sess-url"
check "a PR URL and ticket id name nothing" 0 \
  "$(ptu "$sess-url" Bash 'gh pr view 9117' 'https://github.com/angellist/treasury/pull/9117 BANK-2234 kevinliang/bank-2234-fix Fix a README typo' | wc -c | tr -d ' ')"

print -r -- "-- ranking"
cs() { print -r -- "$2" | MATCH_MIN_TIER=$1 MATCH_CONCEPTS_DIR=/nonexistent "$repo/bin/match.sh" "$db" "${target:t}" | grep -E '^[a-z0-9_]+$' | paste -sd, - }
check "a bare word goes to its biggest concept"   transfer       "$(cs 1 'why is this transfer stuck in pending')"
check "even when a smaller one ends in it"        outgoing_wire  "$(cs 1 'the wire is stuck')"
check "a whole name beats a bare word"            incoming_wire  "$(cs 1 'incoming wire not matched')"
check "a whole name beats its siblings"           book_transfer  "$(cs 1 'book transfer failed')"
check "tool output needs a whole name"            ""             "$(cs 2 'Merge when green. Changes: adds a migration and a lock around the callback')"
check "and a one-word name is a bare word"        ""             "$(cs 2 'see the event log; I put a hold on the transfer')"
check "words never join across a sentence"        ""             "$(cs 2 'check the account. Merge when green')"
check "or across JSON strings"                    ""             "$(cs 2 '{"sub":"account"}')"
check "or across lines"                           ""             "$(cs 2 $'check the account\nmerge')"
check "or a semicolon"                            ""             "$(cs 2 'check the account; merge')"
check "or a question mark"                        ""             "$(cs 2 'check the account? merge')"
check "a pipe in the text is a boundary too"     incoming_wire  "$(cs 2 '|incoming wire|')"
check "a pasted constant names its concept"       incoming_wire  "$(cs 2 'IncomingWires::AutoAssignService#call raised')"
check "a plural inside a whole name is answered"  outgoing_transfers_file "$(cs 1 'the outgoing transfers file is wrong')"
check "a one-word concept keeps its own name"     yes            "$(cs 1 'fund rollover failed' | tr , '\n' | grep -qx fund && print yes || print no)"
check "a plural is one word, not two"             ""             "$(cs 1 'the externals')"
check "STOP words never count toward two"         ""             "$(cs 1 'the account state is wrong')"

print -r -- "-- judgment"
jd=$scratch-concepts
mkdir -p "$jd/${target:t}" || die "concepts dir"
printf '%s\n' '<!-- machine-owned: regenerated every run, never hand-edit -->' '---' 'concept: [treasury, ach_pull]' '---' '<!-- end machine-owned -->' '' '## Judgment' 'Cancel through the state service.' 'src: -Users-x/a.jsonl 2026-10-01T00:00:00Z "quoted"' '' 'Second paragraph.' 'provenance: BANK-1, 2026-10-07' > "$jd/${target:t}/ach_pull.md"
printf '%s\n' '<!-- machine-owned: regenerated every run, never hand-edit -->' '---' 'concept: [treasury, ach_push]' '---' '<!-- end machine-owned -->' '' '## Judgment' > "$jd/${target:t}/ach_push.md"
fresh "$sess-jd"
jout=$(jq -nc --arg s "$sess-jd" --arg c "$target" '{session_id:$s,cwd:$c,prompt:"how does an ach pull get submitted"}' \
         | MATCH_CONCEPTS_DIR=$jd retrieve UserPromptSubmit | ctx)
check "a matched concept carries its judgment" yes "$(print -r -- "$jout" | grep -q 'Cancel through the state service.' && print yes || print no)"
check "without its heading"               0   "$(print -r -- "$jout" | grep -c '## Judgment')"
check "and without its blank lines"       yes "$(print -r -- "$jout" | grep -q '^    Second paragraph.$' && ! print -r -- "$jout" | sed -n '/^  judgment /,$p' | grep -q '^ *$' && print yes || print no)"
fresh "$sess-cap2"
check "the label says how to weigh it"   1   "$(print -r -- "$jout" | grep -c "^  judgment (Kevin's recorded decisions; follow them over your own inference, but check the code before acting on one):$")"
check "citation lines stay out"           0   "$(print -r -- "$jout" | grep -cE '^ *(src|provenance):')"
check "a long judgment is cut to the cap" yes "$(jq -nc --arg s "$sess-cap2" --arg c "$target" '{session_id:$s,cwd:$c,prompt:"how does an ach pull get submitted"}' | MATCH_JUDGMENT_BYTES=10 MATCH_CONCEPTS_DIR=$jd retrieve UserPromptSubmit | ctx | grep -q '^    Cancel thr$' && print yes || print no)"
fresh "$sess-jd2"
check "an empty judgment adds nothing"    0   "$(jq -nc --arg s "$sess-jd2" --arg c "$target" '{session_id:$s,cwd:$c,prompt:"how does an ach push get submitted"}' | MATCH_CONCEPTS_DIR=$jd retrieve UserPromptSubmit | ctx | grep -c '^  judgment ')"
rm -rf "$jd"

print -r -- "-- a stale graph with the lock held"
# The whole staleness path is otherwise never executed: the stamp equals HEAD in this
# environment, so rebuild() is never called and anything about locking is untestable.
# Note what is NOT covered: the lock's owner check only matters when two sessions
# overlap, which this suite cannot stage deterministically.
st=$scratch-stale.db
cp "$db" "$st" || die "copy db for stale"
sqlite3 "$st" "UPDATE graph_stamp SET head_sha = 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'" || die "stale stamp"
lk=$st.lock
rm -rf "$lk"; mkdir "$lk" || die "take lock"
print -r -- 999999 > "$lk/owner"
stout=$(MEMORY_GRAPH_DB=$st CLAUDE_PROJECT_DIR=$target "$repo/hooks/memory-graph.sh" | ctx)
check "it says another session is rebuilding" yes "$(print -r -- "$stout" | grep -q 'another session is rebuilding' && print yes || print no)"
check "the held lock is left in place"        yes "$( [[ -d $lk ]] && print yes || print no )"
check "and its owner is untouched"            999999 "$(cat "$lk/owner" 2>/dev/null)"
check "the stamp was not advanced"            deadbeefdeadbeefdeadbeefdeadbeefdeadbeef "$(sqlite3 "$st" "SELECT head_sha FROM graph_stamp WHERE repo = '${target:t}'")"
rm -rf "$lk"; rm -f "$st"

print -r -- "-- a concept name under the length floor"
named() { print -r -- "$1" | MATCH_MINLEN=${2:-4} "$repo/bin/match.sh" "$db" treasury | grep -E '^[a-z_]+$' }
check "a short concept name matches in prose"           yes "$(named 'the dibs adapter is broken' 5 | grep -qx dibs && print yes || print no)"
check "a short word that names no concept matches nothing" "" "$(named 'the ach is late')"

print -r -- "-- failing safe"
check "an unknown event is refused"       0 "$(jq -nc '{prompt:"x"}' | retrieve Nonsense | wc -c | tr -d ' ')"
check "no event argument is refused"      0 "$(jq -nc '{prompt:"x"}' | MEMORY_GRAPH_DB=$db "$repo/hooks/memory-retrieve.sh" | wc -c | tr -d ' ')"
check "empty stdin is survived"           0 "$(print -n '' | retrieve UserPromptSubmit | wc -c | tr -d ' ')"
check "stdin that is not JSON is survived" 0 "$(print -r -- 'not json at all' | retrieve UserPromptSubmit | wc -c | tr -d ' ')"
check "a cwd that does not exist is survived" SessionStart "$(start /tmp/definitely-not-here-$$ | jq -r '.hookSpecificOutput.hookEventName')"

print ""
print "$pass passed, $fail failed"
(( fail == 0 ))
