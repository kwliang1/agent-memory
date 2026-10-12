#!/bin/zsh
# SessionStart: give a session the memory index its cwd cannot reach on its own.
# UserPromptSubmit: at a cwd above the repos, inject a repo's index the first time a
# prompt names it. Hydra spawns at ~/RubymineProjects, so this is how they get one.
#
# Usage: memory-scope.sh [SessionStart|UserPromptSubmit]   (hook JSON on stdin)
#
# Auto-memory keys the index to cwd. Two gaps follow:
#   - a worktree cwd has its own (empty) scope, so nothing loads
#   - no scope can see any other scope, so cross-repo work has no way in
# This fills both without duplicating what auto-memory already injects: if the cwd's
# own scope has an index, auto-memory loaded it and this adds only the directory.

set -u
command -v jq >/dev/null 2>&1 || exit 0
exec 2>/dev/null
SCOPES=${MEMORY_SCOPES_DIR:-$HOME/agent-memory/scopes}
[ -d "$SCOPES" ] || exit 0

cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
cwd="${cwd%/}"
nl=$'\n'
out=""
marks=${TMPDIR:-/tmp}/memory-scope

slug_of() { local p="${1#/}"; print -r -- "${p//[\/._]/-}" }
has_index() { [ -s "$SCOPES/$(slug_of "$1")/MEMORY.md" ] }

# Claude Code saves hook output over 10,000 characters to a file instead of injecting it.
limit=${MEMORY_SCOPE_LIMIT:-8000}
ceiling=$(( limit + 1500 ))
reserve=0
headings() { print -r -- "$1" | sed -n 's/^## //p' | paste -sd '|' - | sed 's/|/; /g' }
cut_note() { print -r -- "${nl}[cut at the hook output limit; sections left out: ${1:-none}. The rest: \`cat $2\`]$nl" }
add_index() {
  local head="$1$nl$nl" body="$(<"$2")"
  if (( ${#out} + ${#head} + ${#body} + 2 + reserve <= limit )); then out+="$head$body$nl$nl"; return; fi
  local note=$(cut_note "$(headings "$body") (partly); " "$2")
  local room=$(( limit - reserve - ${#out} - ${#head} - ${#note} - 2 ))
  local pointer="Another memory index, left out for length: \`cat $2\`$nl$nl"
  if (( room < 500 )); then (( ${#out} + ${#pointer} <= ceiling )) && out+=$pointer; return 1; fi
  local kept=${body[1,room]}
  kept=${kept%$nl*}
  local rest=${body[${#kept}+1,-1]} left open
  left=$(headings "$rest")
  open=$(print -r -- "$kept" | sed -n 's/^## //p' | tail -1)
  [ -n "$open" ] && left="$open (partly)${left:+; $left}"
  out+="$head$kept$(cut_note "$left" "$2")$nl$nl"
}

if [ "${1:-SessionStart}" = UserPromptSubmit ]; then
  source "${0:A:h:h}/bin/prompt-text.zsh"
  payload=$(cat)
  session=$(print -r -- "$payload" | jq -r '.session_id // empty')
  [[ "$session" =~ '^[A-Za-z0-9_-]+$' ]] || exit 0
  text=$(human_prompt "$(print -r -- "$payload" | jq -r '.prompt // empty')") || exit 0
  named=()
  for child in "$cwd"/*(-/N); do
    scope="$SCOPES/$(slug_of "$child")"
    [ -s "$scope/MEMORY.md" ] || continue
    [ -e "$marks-$session.${scope:t}" ] && continue
    at=$(print -r -- "$text" | grep -oiE -b "(^|[^a-z0-9-])${child:t:gs/./\\.}([^a-z0-9]|\$)" | head -1)
    [ -n "$at" ] && named+=("$(printf '%08d' ${at%%:*}) $child")
  done
  for entry in ${(o)named}; do
    child=${entry#* }
    name=${child:t}
    scope="$SCOPES/$(slug_of "$child")"
    mark="$marks-$session.${scope:t}"
    add_index "This session named \`$name\`, so its memory index follows, once per session. The files it lists are in \`$scope/\`." "$scope/MEMORY.md" && : > "$mark"
  done
  [ -n "$out" ] || exit 0
  printf '%s' "$out" | jq -Rs '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:.}}'
  exit 0
fi

payload=$(cat)
if [ "$(print -r -- "$payload" | jq -r '.source // empty')" = compact ]; then
  session=$(print -r -- "$payload" | jq -r '.session_id // empty')
  [[ "$session" =~ '^[A-Za-z0-9_-]+$' ]] && rm -f "$marks-$session".*(N)
fi

parent=""
if ! has_index "$cwd"; then
  # Ask git for the main worktree root rather than deriving it from the git dir: deriving
  # gets bare repos, separate-git-dir and submodules wrong, and hands them whatever scope
  # their container happens to have. Clear the GIT_* env too — inheriting GIT_DIR from a
  # git hook makes `git -C` ignore cwd entirely and answer for the wrong repo.
  root=$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR \
         git -C "$cwd" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
  if [ -n "$root" ]; then
    # compare canonically; a symlinked or /tmp-vs-/private/tmp cwd is still its own root
    [ "${root:A}" != "${cwd:A}" ] && parent="$root"
  else
    case "$cwd" in
      */conductor/workspaces/*)
        leaf="${cwd##*/conductor/workspaces/}"; leaf="${leaf%%/*}"
        [ -d "$HOME/RubymineProjects/$leaf" ] && has_index "$HOME/RubymineProjects/$leaf" && parent="$HOME/RubymineProjects/$leaf"
        ;;
      *)
        # No git answer means a worktree whose gitdir was pruned. Its .git is still a FILE
        # holding `gitdir: <repo>/.git/worktrees/<name>` — read the pointer rather than
        # guessing from the directory name. Guessing both missed the two commonest layouts
        # and could hand an unrelated `treasury-dashboard-fix` the treasury index.
        if [ -f "$cwd/.git" ]; then
          gd="$(<"$cwd/.git")"
          gd="${gd#gitdir: }"
          gd="${gd%%$'\n'*}"
          gd="${gd%/worktrees/*}"
          [ -n "$gd" ] && [ "${gd:t}" = ".git" ] && parent="${gd:h}"
        fi
        ;;
    esac
  fi
fi

dir=""
for d in "$SCOPES"/*(-/N); do
  idx="$d/MEMORY.md"
  [ -s "$idx" ] || continue
  n=$(grep -aoE '\]\([^)]+\.md\)' "$idx" 2>/dev/null | sort -u | wc -l | tr -d ' ')
  files=("$d"/*.md(N-.))
  total=$(( ${#files[@]} - 1 ))
  [ "$total" -gt 0 ] || [ "$n" -gt 0 ] || continue
  dir+="  ${d:t} — $n indexed of $total$nl"
done

listing=""
if [ -n "$dir" ]; then
  listing+="Memory scopes on this machine (only your own cwd's index is loaded automatically):$nl$nl"
  listing+="$dir$nl"
  listing+="To read another scope: \`cat $SCOPES/<name>/MEMORY.md\`. Files live beside it in the same directory.$nl"
fi

if [ -n "$parent" ]; then
  pslug=$(slug_of "$parent")
  if [ -s "$SCOPES/$pslug/MEMORY.md" ]; then
    reserve=${#listing}
    add_index "This session is inside \`${parent:t}\`, and its index follows — your own cwd has none of its own. If this is a worktree, a memory you save goes away with the directory: to keep one, write it to \`$SCOPES/$pslug/\` and add a pointer to that MEMORY.md." "$SCOPES/$pslug/MEMORY.md"
  fi
fi
out+="$listing"

[ -n "$out" ] || exit 0
printf '%s' "$out" | jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}'
