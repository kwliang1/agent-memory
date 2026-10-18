#!/bin/zsh
# memory-scope.sh UserPromptSubmit: a session at a cwd above the repos gets a repo's
# index the first time a prompt names that repo, and never twice.
set -uo pipefail
export LC_ALL=C
unset CLAUDE_PROJECT_DIR
unset MEMORY_SCOPE_LIMIT
here=${0:A:h}
repo=${here:h}
hook=$repo/hooks/memory-scope.sh

pass=0; fail=0
check() {
  local what=$1 want=$2 got=$3
  if [[ $want == "$got" ]]; then print "ok    $what"; pass=$((pass+1))
  else print "FAIL  $what"; print "        want: $want"; print "        got:  $got"; fail=$((fail+1)); fi
}

tmp=$(mktemp -d) || exit 1; tmp=${tmp:A}
trap 'rm -rf "$tmp"' EXIT
export TMPDIR=$tmp/marks/
mkdir -p "$TMPDIR" "$TMPDIR/memory-scope-a"; : > "$TMPDIR/keep.x"
umbrella=$tmp/projects
mkdir -p $umbrella/alpha $umbrella/beta $umbrella/gamma_x $umbrella/d.ot $umbrella/noscope
scopes=$tmp/scopes
slug() { local p="${1#/}"; print -r -- "${p//[\/._]/-}" }
for r in alpha beta gamma_x d.ot; do
  mkdir -p "$scopes/$(slug $umbrella/$r)"
  print -r -- "INDEX-$r [m](m.md)" > "$scopes/$(slug $umbrella/$r)/MEMORY.md"; : > "$scopes/$(slug $umbrella/$r)/m.md"
done
mkdir -p $umbrella/emptyidx "$scopes/$(slug $umbrella/emptyidx)"; : > "$scopes/$(slug $umbrella/emptyidx)/MEMORY.md"
mkdir -p $umbrella/big "$scopes/$(slug $umbrella/big)"
{ print INDEX-big; for i in {1..400}; do (( i % 100 == 1 )) && print "## Part $i"; print -r -- "- [note $i](n$i.md) — a line of index text"; done; print BIGEND } > "$scopes/$(slug $umbrella/big)/MEMORY.md"
mkdir -p $umbrella/huge "$scopes/$(slug $umbrella/huge)"
{ print INDEX-huge; for i in {1..400}; do print -r -- "- [note $i](n$i.md) — another line of index text"; done; print HUGEEND } > "$scopes/$(slug $umbrella/huge)/MEMORY.md"
mkdir -p $umbrella/mid "$scopes/$(slug $umbrella/mid)"
{ print INDEX-mid; for i in {1..150}; do print -r -- "- [note $i](n$i.md) — a line of index text"; done; print MIDEND } > "$scopes/$(slug $umbrella/mid)/MEMORY.md"
mkdir -p $umbrella/flat "$scopes/$(slug $umbrella/flat)"
{ print -n INDEX-flat; for i in {1..500}; do print -n " word$i"; done; print } > "$scopes/$(slug $umbrella/flat)/MEMORY.md"
mkdir -p $tmp/elsewhere "$scopes/$(slug $umbrella/linked)"; ln -s $tmp/elsewhere $umbrella/linked; print -r -- INDEX-linked > "$scopes/$(slug $umbrella/linked)/MEMORY.md"
mkdir -p "$scopes/$(slug $umbrella)";print -r -- "INDEX-umbrella" > "$scopes/$(slug $umbrella)/MEMORY.md"

ask() { jq -nc --arg p "$1" --arg s "$2" --arg c "${4:-${3:-$umbrella}}" '{session_id:$s,cwd:$c,prompt:$p}' \
          | MEMORY_SCOPES_DIR=$scopes CLAUDE_PROJECT_DIR=${3:-$umbrella} zsh "$hook" UserPromptSubmit }
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' }
idx() { ask "$@" | ctx | grep -o 'INDEX-[a-z_.]*' | paste -sd, - }

check "a named repo gets its index"           INDEX-alpha        "$(idx 'why is alpha slow' s1)"
check "with the event name it fired on"       UserPromptSubmit   "$(ask 'beta' s1b | jq -r .hookSpecificOutput.hookEventName)"
check "marks live in TMPDIR"                  1                  "$(ls $TMPDIR | grep -c '^memory-scope-s1\.')"
check "only once per session"                 ""                 "$(idx 'alpha again' s1)"
check "another repo still loads later"        INDEX-beta         "$(idx 'now beta' s1)"
check "two repos in one prompt"               INDEX-alpha,INDEX-beta "$(idx 'alpha calls beta' s2)"
check "a name with an underscore"             INDEX-gamma_x      "$(idx 'gamma_x broke' s3)"
check "a dot in a name is literal"            ",INDEX-d.ot"      "$(idx 'dxot' s3b),$(idx 'see d.ot' s3c)"
check "case does not matter"                  INDEX-alpha        "$(idx 'ALPHA' s4)"
check "a word starting with the name is not it" ""                "$(idx 'alphabet soup' s5)"
check "a word ending with the name is not it" ""                 "$(idx 'subalpha' s5b)"
check "no repo named, nothing"                ""                 "$(idx 'look at BANK-1234' s6)"
check "not even an empty hook result"         0                  "$(ask 'look at BANK-1234' s6b | wc -c | tr -d ' ')"
check "a dir with no scope is skipped"        0                  "$(ask 'noscope' s7 | ctx | grep -c 'session named')"
check "an empty index is skipped"             0                  "$(ask 'emptyidx' s7b | ctx | grep -c 'session named')"
check "a [system] line is ignored"            ""                 "$(idx '[system] alpha spawned' s7c)"
check "envelope attributes do not count"      ""                 "$(idx '<channel source="alpha-bridge" user="Kevin Liang">hello</channel>' s7d)"
check "a hydra prompt counts only its requests" INDEX-beta,INDEX-gamma_x "$(idx $'<hydra-prompt>\nYou are alpha, a spawned session. Topic: <request>fix the login\n\nthen beta</request>\nRead alpha.\nnote: "<request>also gamma_x</request>"\n</hydra-prompt>' s8)"
check "one with no request names no repo"     ""                 "$(idx $'<hydra-prompt>\nYou are alpha, a resurrected session.\n</hydra-prompt>' s8b)"
check "and no person wrote it"                1                  "$(source $repo/bin/prompt-text.zsh; human_prompt $'<hydra-prompt>\nYou are alpha.\n</hydra-prompt>' >/dev/null; print $?)"
check "a person mentioning the tag is kept"   INDEX-alpha        "$(idx 'does the <hydra-prompt> wrapper reach alpha?' s8g)"
check "so is one pasting a hydra prompt"     INDEX-alpha        "$(idx 'see: <hydra-prompt>'$'\n''about alpha' s8j)"
check "or opening with the tag"               INDEX-alpha        "$(idx '<hydra-prompt> is in alpha?' s8k)"
check "a request may quote a traffic marker"   INDEX-alpha        "$(idx $'<hydra-prompt>\nTopic: <request>why does <task-notification> skip alpha?</request>\n</hydra-prompt>' s8m)"
check "or a reminder, kept whole"              INDEX-alpha        "$(idx $'<hydra-prompt>\nTopic: <request>see <system-reminder>alpha</system-reminder></request>\n</hydra-prompt>' s8n)"
check "or open with [system]"                  INDEX-alpha        "$(idx $'<hydra-prompt>\nTopic: <request>[system] lines in alpha</request>\n</hydra-prompt>' s8o)"
check "or hold a backslash"                   INDEX-alpha        "$(idx $'<hydra-prompt>\nTopic: <request>open C:\\code\\alpha now</request>\n</hydra-prompt>' s8p)"
check "an idle notice from a session is ignored" ""              "$(idx '[Cross-session idle notice] "alpha-pulse-84" is idle' s9e)"
check "but a person quoting one is kept"     INDEX-alpha        "$(idx 'why does [Cross-session idle notice] name alpha?' s9f)"
check "as is any other bracketed start"       INDEX-alpha        "$(idx '[Image #1] see alpha' s9g)"
check "a symlinked repo counts"               INDEX-linked       "$(idx 'see linked' s8l)"
check "an org slug ending in a repo is not it" ""                 "$(idx 'buildkite.com/angellist-alpha/builds/1' s8h)"
check "a repo before a dash still counts"     INDEX-alpha        "$(idx 'see alpha-worktrees/x' s8i)"
check "a system relay is ignored"             ""                 "$(idx '<channel source="x" user="system" user_id="system">alpha</channel>' s9)"
check "so is a bot's"                         ""                 "$(idx '<channel source="x" user="pr-watch" user_id="system">alpha</channel>' s9b)"
check "and another session's"                 ""                 "$(idx '<channel source="x" user="atlas" user_id="session">alpha</channel>' s9c)"
check "but not a person quoting the attribute" INDEX-alpha       "$(idx '<channel source="x" user="K" user_id="U1">why is alpha user_id="system"?</channel>' s9d)"
check "a task notification is ignored"        ""                 "$(idx '<task-notification>alpha done</task-notification>' s10)"
check "a reminder does not count"             ""                 "$(idx '<system-reminder>alpha</system-reminder>hello' s11)"
check "the bridge envelope is stripped"       INDEX-alpha        "$(idx '<channel source="slack" user="Kevin Liang">check alpha</channel>' s12)"
check "an unsafe session id is refused"       ""                 "$(idx 'alpha' '../x')"
check "so is one with a path inside"          "0,"               "$(o=$(idx 'alpha' 'a/../x'); print -r -- "$(ls $TMPDIR | grep -c 'x\.')",$o)"
check "the start dir wins over a cd"          INDEX-beta         "$(idx 'beta' s13 $umbrella $umbrella/alpha)"
check "repos load in the order named"         INDEX-gamma_x,INDEX-alpha "$(idx 'so gamma_x then alpha' s14)"
check "so the first named gets the budget"    "1,0"              "$(o=$(ask 'huge before big' s14b | ctx); print -r -- "$(grep -c 'INDEX-huge' <<<$o),$(grep -c 'INDEX-big' <<<$o)")"
check "a long index is cut under the limit"   yes                "$(n=$(ask 'big' s15 | ctx | wc -m); (( n > 7000 && n <= 8000 )) && print yes || print no)"
check "and says where the rest is"            1                  "$(ask 'big' s16 | ctx | grep -c "The rest: \`cat $scopes/$(slug $umbrella/big)/MEMORY.md\`")"
check "an index with no headings stays in budget" "yes,1"       "$(o=$(export MEMORY_SCOPE_LIMIT=3000; ask 'flat' s16c | ctx); (( ${#o} <= 3000 )) && print -n yes, || print -n "no(${#o}),"; grep -c 'sections left out: none\.' <<<$o)"
check "and which sections it left out"        1                  "$(ask 'big' s16b | ctx | grep -c 'sections left out: Part 101 (partly); Part 201; Part 301\.')"
check "a cut ends on a whole line"            1                  "$(ask 'big' s16d | ctx | grep -B1 '^\[cut at' | head -1 | grep -cE '^- \[note [0-9]+\]\(n[0-9]+\.md\) — a line of index text$')"
check "and never reaches its tail"            0                  "$(ask 'big' s17 | ctx | grep -c BIGEND)"
check "a later repo past the limit is a pointer" 1               "$(ask 'big then gamma_x' s18 | ctx | grep -c "left out for length: \`cat $scopes/$(slug $umbrella/gamma_x)/MEMORY.md\`")"
check "an index that fits is whole"           1                  "$(ask 'alpha' s19 | ctx | grep -c 'INDEX-alpha \[m\](m.md)')"
check "and carries no cut marker"             0                  "$(ask 'mid' s19b | ctx | grep -c 'cut at')"
check "a fitting index keeps its last line"   1                  "$(ask 'mid' s19c | ctx | grep -c MIDEND)"
check "a second long index past the limit is only a pointer" "1,0" "$(o=$(ask 'big then huge' s19d | ctx); print -r -- "$(grep -c "left out for length: .*$(slug $umbrella/huge)" <<<$o),$(grep -c 'INDEX-huge' <<<$o)")"
check "pointers stop at the ceiling"          "yes,yes"          "$(o=$(export MEMORY_SCOPE_LIMIT=-1000; ask 'big huge mid alpha beta gamma_x' s19e | ctx); n=$(grep -c 'left out' <<<$o); (( ${#o} <= 500 )) && print -n yes, || print -n no,; (( n > 0 && n < 6 )) && print yes || print "no($n)")"
check "a person's 'You are' prompt is kept whole" INDEX-alpha  "$(idx 'You are right, a fix for alpha is needed' s19f)"
check "a pointer-only repo loads when named again" INDEX-huge    "$(idx 'big then huge' s19i >/dev/null; idx 'huge' s19i)"
check "indented [system] is still ignored"    ""                 "$(idx '   [system] alpha spawned' s19g)"

compact() { jq -nc --arg s "$1" --arg src "$2" '{session_id:$s,source:$src}' | MEMORY_SCOPES_DIR=$scopes CLAUDE_PROJECT_DIR=$umbrella zsh "$hook" >/dev/null }
idx 'alpha' s20 >/dev/null; idx 'alpha' s21 >/dev/null
compact s20 compact
check "after compaction a repo loads again"   INDEX-alpha        "$(idx 'alpha' s20)"
check "but only for the compacted session"    ""                 "$(idx 'alpha' s21)"
compact s21 resume
check "a resume keeps the marks"              ""                 "$(idx 'alpha' s21)"
compact 'a/../keep' compact
check "compaction refuses a path in the session id" 1            "$(ls $TMPDIR | grep -c '^keep\.x$')"

check "SessionStart still lists the scopes"   yes "$(cd $umbrella && MEMORY_SCOPES_DIR=$scopes CLAUDE_PROJECT_DIR=$umbrella zsh "$hook" </dev/null | ctx | grep -q 'Memory scopes on this machine' && print yes || print no)"

tg() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git "$@" }
tg -C $umbrella/big init -q && tg -C $umbrella/big worktree add -q --orphan -b wt $tmp/bigwt
start() { (cd $tmp/${1}wt && MEMORY_SCOPES_DIR=$scopes CLAUDE_PROJECT_DIR=$tmp/${1}wt zsh "$hook" </dev/null | ctx) }
check "a worktree's long parent index is cut"  yes "$(n=$(start big | wc -m); (( n > 7000 && n <= 8000 )) && print yes || print no)"
check "with room left for the scope listing"  1   "$(start big | grep -c 'Memory scopes on this machine')"
check "after the cut parent index"            yes "$(o=$(start big); (( $(grep -n 'Memory scopes' <<<$o | cut -d: -f1) > $(grep -n 'cut at the hook' <<<$o | cut -d: -f1) )) && print yes || print no)"
tg -C $umbrella/mid init -q && tg -C $umbrella/mid worktree add -q --orphan -b wt $tmp/midwt
tg -C $umbrella/emptyidx init -q && tg -C $umbrella/emptyidx worktree add -q --orphan -b wt $tmp/emptyidxwt
check "a worktree's empty parent index is skipped" 0             "$(start emptyidx | grep -c 'index follows')"
check "an index that fits only without the listing is cut" yes "$(o=$(start mid); (( ${#o} <= 8000 )) && grep -q 'cut at the hook' <<<$o && print yes || print no)"

print "$pass passed, $fail failed"
(( fail == 0 ))
