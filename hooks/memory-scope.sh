#!/bin/zsh
# SessionStart: give a session the memory index its cwd cannot reach on its own.
#
# Auto-memory keys the index to cwd. Two gaps follow:
#   - a worktree cwd has its own (empty) scope, so nothing loads
#   - no scope can see any other scope, so cross-repo work has no way in
# This fills both without duplicating what auto-memory already injects: if the cwd's
# own scope has an index, auto-memory loaded it and this adds only the directory.

set -u
command -v jq >/dev/null 2>&1 || exit 0
exec 2>/dev/null
SCOPES="$HOME/claude-memory/scopes"
[ -d "$SCOPES" ] || exit 0

cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
cwd="${cwd%/}"
nl=$'\n'
out=""

slug_of() { local p="${1#/}"; print -r -- "${p//[\/._]/-}" }
has_index() { [ -s "$SCOPES/$(slug_of "$1")/MEMORY.md" ] }

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

if [ -n "$parent" ]; then
  pslug=$(slug_of "$parent")
  body=$(cat "$SCOPES/$pslug/MEMORY.md" 2>/dev/null)
  if [ -n "$body" ]; then
    out+="This session is inside \`${parent:t}\`, and its index follows — your own cwd has none of its own. If this is a worktree, a memory you save goes away with the directory: to keep one, write it to \`$SCOPES/$pslug/\` and add a pointer to that MEMORY.md.$nl$nl"
    out+="$body$nl$nl"
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

if [ -n "$dir" ]; then
  out+="Memory scopes on this machine (only your own cwd's index is loaded automatically):$nl$nl"
  out+="$dir$nl"
  out+="To read another scope: \`cat $SCOPES/<name>/MEMORY.md\`. Files live beside it in the same directory.$nl"
fi

[ -n "$out" ] || exit 0
printf '%s' "$out" | jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}'
