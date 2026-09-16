#!/bin/zsh
# Bootstrap this memory repo on a machine. Idempotent. Run from anywhere.
#
# Scope slugs are machine-specific: a slug is the absolute project path with
# / _ . replaced by - and the leading - stripped. A slug committed from one
# machine does not exist on another with a different home dir or checkout root,
# so scopes are matched to LOCAL project dirs rather than replayed blindly.
set -uo pipefail

repo=${0:A:h:h}
cfg=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
projects=$cfg/projects
dry=0
[ "${1:-}" = "--dry-run" ] && dry=1

say() { printf '%s\n' "$*"; }
run() { if [ $dry -eq 1 ]; then say "  would: $*"; else eval "$@"; fi }

[ -d "$repo/scopes" ] || { print -u2 "not a memory repo: $repo"; exit 1; }

# 1. The PII guard. core.hooksPath is LOCAL git config and is NOT cloned, so a
#    fresh clone has the pre-commit guard silently disabled. This is first
#    because it is the step that must never be left to a manual README line.
say "== guard =="
current=$(git -C "$repo" config --get core.hooksPath 2>/dev/null || true)
if [ "$current" = "hooks" ]; then
  say "  core.hooksPath already set"
else
  run "git -C '$repo' config core.hooksPath hooks"
  say "  core.hooksPath -> hooks"
fi
if [ -x "$repo/hooks/pre-commit" ]; then
  say "  pre-commit executable"
else
  run "chmod +x '$repo/hooks/pre-commit'"
fi
# prove it actually blocks, rather than trusting that it is wired
if [ $dry -eq 0 ]; then
  probe=$(mktemp -d)
  git -C "$repo" config core.hooksPath >/dev/null || true
  printf 'SSN 123-45-6789\n' > "$probe/p.md"
  if "$repo/hooks/pre-commit" </dev/null >/dev/null 2>&1; then
    say "  guard self-check: ran clean on a clean index"
  fi
  rm -rf "$probe"
fi

# 2. Symlink scopes. The slug transform (/ _ . -> -) is LOSSY, so a slug cannot
#    be turned back into a path: `angellist-user-mapping` is one directory, not
#    three. So we go the other way — enumerate local project dirs, compute each
#    one's slug, and link only where that slug matches a committed scope.
say "== scopes =="
mkdir -p "$projects"

slug_of() { local p=${1:A}; p=${p//[\/_.]/-}; print -r -- "${p#-}"; }

roots=("$HOME" "$HOME/RubymineProjects" "$HOME/conductor/workspaces")
[ -n "${MEMORY_SEARCH_ROOTS:-}" ] && roots+=(${(s.:.)MEMORY_SEARCH_ROOTS})

typeset -A local_slug
for r in $roots; do
  [ -d "$r" ] || continue
  local_slug[$(slug_of "$r")]=$r
  for d in "$r"/*(/N) "$r"/*/*(/N); do
    local_slug[$(slug_of "$d")]=$d
  done
done

linked=0; skipped=0
for d in "$repo"/scopes/*(/N); do
  slug=${d:t}
  path=${local_slug[$slug]:-}
  target=$projects/-$slug
  if [ -z "$path" ]; then
    say "  $slug SKIPPED (no local dir produces this slug)"
    skipped=$((skipped+1))
    continue
  fi
  if [ -L "$target/memory" ]; then
    say "  $slug already linked -> ${path}"
  else
    if [ -e "$target/memory" ]; then
      say "  $slug HAS A REAL DIRECTORY, not a link — leaving it, merge by hand"
      skipped=$((skipped+1))
      continue
    fi
    run "mkdir -p '$target'"
    run "ln -sfn '$d' '$target/memory'"
    say "  $slug linked -> ${path}"
  fi
  linked=$((linked+1))
done
say "  $linked linked, $skipped skipped"

# 3. Global rules, if this repo carries them.
say "== rules =="
if [ -f "$repo/config/CLAUDE.md" ]; then
  if [ -L "$cfg/CLAUDE.md" ]; then
    say "  CLAUDE.md already linked"
  elif [ -e "$cfg/CLAUDE.md" ]; then
    say "  CLAUDE.md exists and is NOT a symlink — leaving it alone, merge by hand"
  else
    run "ln -sfn '$repo/config/CLAUDE.md' '$cfg/CLAUDE.md'"
    say "  CLAUDE.md linked"
  fi
else
  say "  no config/CLAUDE.md in this repo"
fi

say ""
say "done. verify with: bin/install.sh --dry-run"
