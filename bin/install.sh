#!/bin/zsh
# Bootstrap this memory repo on a machine. Idempotent. Run from anywhere.
#
# Scope slugs are machine-specific: a slug is the absolute project path with
# / _ . replaced by - and the leading - stripped. That transform is LOSSY, so a
# slug cannot be turned back into a path. We enumerate local project dirs,
# compute each one's slug, and link only where it matches a committed scope.
set -uo pipefail
setopt extended_glob null_glob

here=${0:A:h}
repo=${here:h}
cfg=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
projects=$cfg/projects
dry=0

for a in "$@"; do
  case "$a" in
    --dry-run) dry=1 ;;
    *) print -u2 "unknown argument: $a"; print -u2 "usage: install.sh [--dry-run]"; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*" }
fail=0
# exec argv directly, never eval a hand-quoted string, and check status
run() {
  if [ $dry -eq 1 ]; then say "  would: $*"; return 0; fi
  if ! "$@"; then say "  FAILED: $*"; fail=1; return 1; fi
  return 0
}

[ -d "$repo/scopes" ] || { print -u2 "not a memory repo: $repo"; exit 1 }

# 1. The PII guard. core.hooksPath is LOCAL git config and is NOT cloned, so a
#    fresh clone has hooks/pre-commit silently disabled. First, because it is the
#    step that must never be left to a manual README line.
say "== guard =="
if [ "$(git -C "$repo" config --get core.hooksPath 2>/dev/null)" = "hooks" ]; then
  say "  core.hooksPath already set"
else
  run git -C "$repo" config core.hooksPath hooks && say "  core.hooksPath -> hooks"
fi
[ -x "$repo/hooks/pre-commit" ] || run chmod +x "$repo/hooks/pre-commit"

# Prove the guard BLOCKS, in a throwaway clone. A self-check that only confirms
# "ran clean on a clean index" proves nothing — the hook reads `git diff --cached`
# with no -C, so invoked outside a repo it exits non-zero and says nothing.
if [ $dry -eq 0 ]; then
  probe=$(mktemp -d)
  if git clone -q "$repo" "$probe/p" 2>/dev/null; then
    (
      cd "$probe/p" || exit 1
      git config core.hooksPath hooks
      mkdir -p scopes/_probe
      printf 'synthetic probe 123-45-6789\n' > scopes/_probe/p.md
      git add scopes/_probe/p.md 2>/dev/null
      if git commit -q -m probe >/dev/null 2>&1; then exit 1; else exit 0; fi
    )
    if [ $? -eq 0 ]; then say "  guard self-check: BLOCKS a synthetic SSN"
    else say "  guard self-check: FAILED TO BLOCK — do not push from this clone"; fail=1; fi
  else
    say "  guard self-check: skipped (could not clone)"
  fi
  rm -rf "$probe"
fi

# 2. Symlink scopes.
say "== scopes =="
run mkdir -p "$projects" || exit 1

slug_of() { local p=${1:A}; p=${p//[\/_.]/-}; print -r -- "${p#-}" }

roots=("$HOME" "$HOME/RubymineProjects" "$HOME/conductor/workspaces")
[ -n "${MEMORY_SEARCH_ROOTS:-}" ] && roots+=(${(s.:.)MEMORY_SEARCH_ROOTS})

# (D) is required: .worktrees/ is dot-hidden, and without it every worktree scope
# is permanently unreachable — which is the problem this repo exists to solve.
typeset -A found
for r in $roots; do
  [ -d "$r" ] || continue
  found[$(slug_of "$r")]=$r
  for d in "$r"/*(/DN) "$r"/*/*(/DN) "$r"/*/*/*(/DN); do
    s=$(slug_of "$d")
    [ -n "${found[$s]:-}" ] && continue   # first root wins, deterministically
    found[$s]=$d
  done
done

linked=0; already=0; skipped=0
for d in "$repo"/scopes/*(/N); do
  slug=${d:t}
  proj=${found[$slug]:-}
  target=$projects/-$slug
  want=$d

  if [ -z "$proj" ]; then
    say "  $slug SKIPPED (no local dir produces this slug)"
    skipped=$((skipped+1)); continue
  fi

  if [ -L "$target/memory" ]; then
    have=${${:-$(readlink "$target/memory")}:A}
    if [ "$have" = "${want:A}" ]; then
      say "  $slug ok"
      already=$((already+1))
    else
      # a link into an old clone reports "already linked" if you only test -L
      say "  $slug RELINKING (pointed at $have)"
      run ln -sfn "$want" "$target/memory" && linked=$((linked+1))
    fi
    continue
  fi

  if [ -e "$target/memory" ]; then
    # ln -sfn against a real directory exits 0 and plants the link INSIDE it
    say "  $slug HAS A REAL DIRECTORY, not a link — leaving it, merge by hand"
    skipped=$((skipped+1)); continue
  fi

  run mkdir -p "$target" && run ln -sfn "$want" "$target/memory" \
    && { say "  $slug linked -> $proj"; linked=$((linked+1)) }
done
say "  $linked linked, $already already correct, $skipped skipped"

# 3. Global rules.
say "== rules =="
if [ -f "$repo/config/CLAUDE.md" ]; then
  if [ -L "$cfg/CLAUDE.md" ]; then
    have=${${:-$(readlink "$cfg/CLAUDE.md")}:A}
    if [ "$have" = "${repo:A}/config/CLAUDE.md" ]; then
      say "  CLAUDE.md ok"
    else
      say "  CLAUDE.md is a symlink to $have — NOT this repo. Leaving it; resolve by hand."
    fi
  elif [ -e "$cfg/CLAUDE.md" ]; then
    say "  CLAUDE.md is a real file — leaving it alone, merge by hand"
  else
    run ln -sfn "$repo/config/CLAUDE.md" "$cfg/CLAUDE.md" && say "  CLAUDE.md linked"
  fi
else
  say "  no config/CLAUDE.md in this repo"
fi

say ""
if [ $fail -ne 0 ]; then
  print -u2 "install completed WITH FAILURES — see FAILED lines above"
  exit 1
fi
[ $dry -eq 1 ] && say "dry run only. --dry-run cannot detect a broken PATH or a failed exec; re-run without it to install."
exit 0
