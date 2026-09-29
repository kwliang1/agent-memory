#!/bin/zsh
# UserPromptSubmit and PostToolUse: resolve what the session is talking about to real
# symbols and inject them with file:line.
#
# Usage: memory-retrieve.sh <UserPromptSubmit|PostToolUse>   (hook JSON on stdin)
#
# One script for both events because the work is the same -- take some text, match it,
# inject -- and only three things differ: which field carries the text, how much of it
# to trust, and how much of it there is.
set -u
command -v jq      >/dev/null 2>&1 || exit 0
command -v sqlite3 >/dev/null 2>&1 || exit 0
exec 2>/dev/null

event=${1:-}
case $event in
  UserPromptSubmit|PostToolUse) ;;
  *) exit 0 ;;
esac

here=${0:A:h}
root=${here:h}
db=${MEMORY_GRAPH_DB:-$root/index/graph.db}
[ -f "$db" ] || exit 0

payload=$(cat)
[ -n "$payload" ] || exit 0

cwd=$(print -r -- "$payload" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
session=$(print -r -- "$payload" | jq -r '.session_id // empty')

if [ "$event" = UserPromptSubmit ]; then
  text=$(print -r -- "$payload" | jq -r '.prompt // empty')
  tier=1
else
  # tool_response is whatever the tool returned -- a string for some tools, an object
  # for others -- so flatten rather than assume. The cap is on what reaches the
  # tokeniser, not on what jq reads: a 2.6 MB response measured 0.27 s end to end, and
  # in practice the matches all come from the first few thousand bytes.
  text=$(print -r -- "$payload" | jq -r '[.tool_input, .tool_response] | .. | strings' 2>/dev/null | head -c 20000)
  # A prompt is deliberate and a tool result is incidental, so this half asks for the
  # concept NAME to match. Measured on real output: bundler chatter injects three
  # unrelated concepts at tier 1 and none at tier 2, while a real question is unmoved.
  tier=2
fi
[ -n "$text" ] || exit 0

g() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR git "$@" }
main=$(g -C "$cwd" worktree list --porcelain 2>/dev/null | sed -n '1s|^worktree ||p')
repo=""
if [ -n "$main" ]; then
  repo=${main:t}
else
  # The cwd is often not a repo -- most of Kevin's sessions run at ~/RubymineProjects.
  # With one indexed repo there is no ambiguity to resolve; with several there is no
  # honest way to pick, so do not guess.
  n=$(sqlite3 -cmd '.timeout 2000' "$db" "SELECT count(*) FROM graph_stamp")
  [ "$n" = "1" ] && repo=$(sqlite3 -cmd '.timeout 2000' "$db" "SELECT repo FROM graph_stamp")
fi
[ -n "$repo" ] || exit 0
[[ "$repo" =~ '^[A-Za-z0-9._-]+$' ]] || exit 0

# Inject a concept once per session, or every tool call re-injects the same block.
# A repeat question on the same subject therefore injects NOTHING -- the session
# already has those concepts. A new subject still injects, and that is what bounds
# the second hop: expansion follows what the session moves on to, not how often it
# asks about the same thing.
seen=""
if [ -n "$session" ] && [[ "$session" =~ '^[A-Za-z0-9_-]+$' ]]; then
  seen=${TMPDIR:-/tmp}/memory-graph-$session.seen
  [ -f "$seen" ] || : > "$seen"
fi

out=$(print -r -- "$text" | MATCH_MIN_TIER=$tier MATCH_EXCLUDE=${seen:-} MATCH_CHOSEN=${seen:-} \
        "$root/bin/match.sh" "$db" "$repo")
[ -n "$out" ] || exit 0

printf '%s' "$out" | jq -Rs --arg e "$event" \
  '{hookSpecificOutput:{hookEventName:$e,additionalContext:.}}'
