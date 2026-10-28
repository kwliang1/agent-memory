#!/bin/zsh
# UserPromptSubmit and PostToolUse: resolve what the session is talking about to real
# symbols and inject them with file:line.
#
# Usage: memory-retrieve.sh <UserPromptSubmit|PostToolUse>   (hook JSON on stdin)
#
# One script for both events because the work is the same -- take some text, match it,
# inject -- and what differs is which field carries the text, how much of it to trust,
# how much of it there is, and whether it may move an umbrella session's repo binding.
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
source "$root/bin/prompt-text.zsh"
[ -f "$db" ] || exit 0

payload=$(cat)
[ -n "$payload" ] || exit 0

cwd=$(print -r -- "$payload" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
session=$(print -r -- "$payload" | jq -r '.session_id // empty')

if [ "$event" = UserPromptSubmit ]; then
  text=$(human_prompt "$(print -r -- "$payload" | jq -r '.prompt // empty')") || exit 0
  tier=1
else
  # Bash output is the session's own work coming back at it, except gh, which fetches
  # a PR or an issue the same way the Slack and Linear tools fetch a thread.
  if [ "$(print -r -- "$payload" | jq -r '.tool_name // empty')" = Bash ]; then
    print -r -- "$payload" | jq -r '.tool_input.command // empty' \
      | grep -qE '(^|[;&|(]|xargs)[[:space:]]*gh +(pr|issue|api|run|search) ' || exit 0
  fi
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
top() { g -C "$1" worktree list --porcelain 2>/dev/null | sed -n '1s|^worktree ||p' }
owner=""
if [ "$event" = PostToolUse ]; then
  fp=$(print -r -- "$payload" | jq -r '.tool_input.file_path // .tool_input.path // empty')
  if [[ "$fp" == /* ]]; then
    while [ ! -d "$fp" ]; do fp=${fp:h}; done
    owner=$(top "$fp")
  fi
fi
# The cwd is often not a repo -- most of Kevin's sessions run at ~/RubymineProjects.
repo=${${owner:-$(top "$cwd")}:t}

base=""
[ -n "$session" ] && [[ "$session" =~ '^[A-Za-z0-9_-]+$' ]] && base=${TMPDIR:-/tmp}/memory-graph-$session
bound=""
[ -n "$base" ] && [ -s "$base.bound" ] && bound=$(<"$base.bound")
indexed=(${(f)"$(sqlite3 -cmd '.timeout 2000' "$db" "SELECT repo FROM graph_stamp ORDER BY repo")"})

# At a cwd that is no repo, guessing a repo was a bad idea: 100 umbrella sessions got
# treasury symbols whatever they were about. Bind the session to the indexed repo that a
# file it touches belongs to, or that its text names first, and stay silent until then.
# Only a prompt moves an existing binding: a file listing that names every repo is not a
# change of subject.
pick=""
if [ -n "$owner" ]; then
  [ -z "$bound" ] && (( ${indexed[(Ie)$repo]} )) && pick=$repo
elif [ -z "$repo" ]; then
  if [ -n "$bound" ] && [ "$event" != UserPromptSubmit ]; then
    repo=$bound
  else
    first=-1
    for r in $indexed; do
      [[ "$r" =~ '^[A-Za-z0-9._-]+$' ]] || continue
      at=$(print -r -- "$text" | grep -aoibE "(^|[^a-z0-9])${r//./\\.}([^a-z0-9]|\$)" | head -n 1 | cut -d: -f1)
      [ -n "$at" ] || continue
      if (( first < 0 || at < first )); then first=$at; pick=$r; fi
    done
    repo=${pick:-$bound}
    [ -n "$repo" ] || exit 0
  fi
fi
[ -n "$base" ] && [ -n "$pick" ] && [ "$pick" != "$bound" ] && print -r -- "$pick" > "$base.bound.$$" && mv -f "$base.bound.$$" "$base.bound"
[[ "$repo" =~ '^[A-Za-z0-9._-]+$' ]] || exit 0
# Purely an optimization, and deliberately untested: with no rows the matcher finds
# nothing either way, so no assertion on output can tell this guard from its absence.
# It is here for time -- a nova session measured 4.81 s across 20 calls to inject zero
# bytes, against 0.0078 s for this query.
[ -n "$(sqlite3 -cmd '.timeout 2000' "$db" \
    "SELECT 1 FROM node WHERE repo = '${repo//\'/\'\'}' LIMIT 1")" ] || exit 0

# Inject a concept once per session and repo, or every tool call re-injects the same block.
# A repeat question on the same subject therefore injects NOTHING -- the session
# already has those concepts. A new subject still injects, and that is what bounds
# the second hop: expansion follows what the session moves on to, not how often it
# asks about the same thing.
seen=""
if [ -n "$base" ]; then
  seen=$base.$repo.seen
  [ -f "$seen" ] || : > "$seen"
fi

# A budget, because the taper alone is not a bound. Injection is heavily front-loaded
# -- measured over 141 distinct treasury model reads: ~1,300 bytes at read 1, ~200 by
# read 40, 72 KB in total. The first couple of dozen reads carry nearly all the value,
# so past this many distinct symbols a tool result stops earning its tokens. A
# deliberate prompt is never capped.
if [ "$event" = PostToolUse ] && [ -n "$seen" ]; then
  (( $(wc -l < "$seen") < ${MEMORY_GRAPH_MAX_SEEN:-250} )) || exit 0
fi

out=$(print -r -- "$text" | MATCH_MIN_TIER=$tier MATCH_EXCLUDE=${seen:-} MATCH_CHOSEN=${seen:-} \
        "$root/bin/match.sh" "$db" "$repo")
[ -n "$out" ] || exit 0

printf '%s' "$out" | jq -Rs --arg e "$event" \
  '{hookSpecificOutput:{hookEventName:$e,additionalContext:.}}'
