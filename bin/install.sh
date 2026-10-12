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
if [ ! -f "$repo/hooks/pre-commit" ]; then
  say "  MISSING hooks/pre-commit in this working tree — the PII guard cannot run"
  fail=1
elif [ ! -x "$repo/hooks/pre-commit" ]; then
  run chmod +x "$repo/hooks/pre-commit"
fi

# Prove the guard BLOCKS, and blocks *for the right reason*. A check that maps any
# commit failure to "BLOCKS" passes with the hook deleted — verified. So require the
# hook's own rejection text in stderr.
if [ $dry -eq 0 ]; then
  probe=$(mktemp -d)
  if git clone -q "$repo" "$probe/p" 2>/dev/null; then
    out=$(
      cd "$probe/p" || exit 9
      git config core.hooksPath hooks
      git config user.email probe@local; git config user.name probe
      mkdir -p scopes/_probe
      printf 'synthetic probe 123-45-6789\n' > scopes/_probe/p.md
      git add scopes/_probe/p.md >/dev/null 2>&1 || exit 9
      git commit -m probe 2>&1
      print "COMMIT_EXIT=$?"
    )
    if print -r -- "$out" | grep -q 'COMMIT_EXIT=0'; then
      say "  guard self-check: FAILED TO BLOCK — do not push from this clone"; fail=1
    elif print -r -- "$out" | grep -q 'refusing — regulated identifiers'; then
      say "  guard self-check: BLOCKS a synthetic SSN, with the hook's own message"
    else
      say "  guard self-check: commit failed but NOT by the guard — inconclusive"
      print -u2 "$out" | head -3
      fail=1
    fi
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

# (-/DN): D because .worktrees/ is dot-hidden and without it every worktree scope is
# unreachable — the problem this repo exists to solve. The leading - follows symlinked
# directories: plain (/DN) sees only real dirs, so a project reached through a symlink
# is silently SKIPPED as "no local dir produces this slug".
typeset -A found
for r in $roots; do
  [ -d "$r" ] || continue
  found[$(slug_of "$r")]=$r
  for d in "$r"/*(-/DN) "$r"/*/*(-/DN) "$r"/*/*/*(-/DN); do
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

# 4. Claude Code hooks. settings.json is NOT in this repo -- it is the live config every
#    session reads, including the ones running right now -- so this adds only what is
#    missing, and on our own entries updates nothing but the matcher. Keyed on the command
#    string, so an existing SessionStart hook keeps its place.
say "== claude hooks =="
settings=$cfg/settings.json
if ! command -v jq >/dev/null 2>&1; then
  say "  jq is not on PATH — skipping, the hooks stay unwired"
elif [ ! -f "$repo/hooks/memory-graph.sh" ]; then
  say "  hooks/memory-graph.sh is missing from this working tree — skipping"
  elif common=$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && [ "${common:A}" != "${repo:A}/.git" ]; then
  # A linked worktree can be torn down, and then every session errors on every prompt
  # and every tool call. Installing from a second checkout doubles all three hooks
  # rather than replacing them, because the key is the full command string.
  say "  $repo is a linked worktree - refusing to wire hooks to a path that can be torn down"
  say "  run install.sh from the main checkout instead"
  fail=1
else
  backed_up=""
  retrieve_tools='^(Read|Grep|Glob|WebFetch|Bash|mcp__.*__(slack_read_thread|slack_read_channel|slack_search_public|slack_search_public_and_private|fetch_messages|get_issue|list_comments|issue_read|pull_request_read|get_file_contents))$'
  register() {
    local event=$1 cmd=$2 matcher=${3:-}
    local before after tmpf
    # Every other mutation here routes through run(), which honours $dry. This one
    # bypassed it -- and install.sh is a fresh-machine bootstrap, which is exactly when
    # settings.json is absent.
    if [ ! -f "$settings" ]; then
      if [ $dry -eq 1 ]; then say "  would create $settings"; return 0; fi
      printf '{}\n' > "$settings"
    fi
    if ! jq -e . "$settings" >/dev/null 2>&1; then
      say "  $settings is not valid JSON — leaving it alone, wire $event by hand"
      fail=1
      return 1
    fi
    before=$(jq -S . "$settings")
    tmpf=$(mktemp) || return 1
    # A matcher of "" is how Claude Code spells "every tool", and jq must emit the key
    # only when we mean it -- an unexpected null matcher is not the same thing.
    if jq --arg e "$event" --arg c "$cmd" --arg m "$matcher" '
         def entry: if $m == "" then {hooks: [{type: "command", command: $c}]}
                    else {matcher: $m, hooks: [{type: "command", command: $c}]} end;
         .hooks //= {}
         | .hooks[$e] //= []
         | if [.hooks[$e][]?.hooks[]?.command] | index($c) then
             if $m == "" then .
             else .hooks[$e] |= map(if any(.hooks[]?; .command == $c) and all(.hooks[]?; .command == $c) then .matcher = $m else . end) end
           else .hooks[$e] += [entry] end
       ' "$settings" > "$tmpf" 2>/dev/null && [ -s "$tmpf" ] && jq -e . "$tmpf" >/dev/null 2>&1; then
      after=$(jq -S . "$tmpf")
      if [ "$before" = "$after" ]; then
        if [ -n "$matcher" ] && jq -e --arg e "$event" --arg c "$cmd" --arg m "$matcher" \
             '[.hooks[$e][]? | select(any(.hooks[]?; .command == $c)) | .matcher] | any(. != $m)' "$settings" >/dev/null 2>&1; then
          say "  $event wired, but its matcher was left alone: it shares a group with another hook"
        else
          say "  $event already wired"
        fi
        rm -f "$tmpf"
      elif [ $dry -eq 1 ]; then
        say "  would wire: $event -> $cmd"
        rm -f "$tmpf"
      else
        # Taken inside each of the three registers, the second and third clobbered it with a
        # file that already held the earlier hooks -- so restoring it did not undo the
        # install, and the message saying it would was false.
        if [ -z "$backed_up" ] && [ -f "$settings" ]; then
          cp "$settings" "$settings.bak" 2>/dev/null && backed_up=1
        fi
        mv "$tmpf" "$settings" && say "  wired $event -> $cmd${matcher:+ (matcher: $matcher)}"
      fi
    else
      rm -f "$tmpf"
      say "  could not update $settings for $event — left unchanged"
      fail=1
    fi
  }
  register SessionStart     "$repo/hooks/memory-graph.sh"
  register UserPromptSubmit "$repo/hooks/memory-retrieve.sh UserPromptSubmit"
  register SessionStart     "$repo/hooks/memory-scope.sh"
  register UserPromptSubmit "$repo/hooks/memory-scope.sh UserPromptSubmit"
  # Only the tools that FETCH something: files, and the Slack threads, Linear issues and
  # PRs a session is started from. Bash is matched for gh alone; the hook drops the rest.
  # An existing entry's matcher is updated in place, so re-running picks up a change here.
  register PostToolUse      "$repo/hooks/memory-retrieve.sh PostToolUse" "$retrieve_tools"
fi

# 5. The reindex job: every 15 minutes, rebuild any graph whose repo's origin/main moved.
#    Same linked-worktree refusal as the hooks, for the same reason.
say "== reindex job =="
label=com.agent-memory.reindex
plist=$HOME/Library/LaunchAgents/$label.plist
if [ "$(uname)" != Darwin ]; then
  say "  not macOS — schedule bin/reindex.sh with cron by hand"
elif common=$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && [ "${common:A}" != "${repo:A}/.git" ]; then
  say "  $repo is a linked worktree - refusing to schedule a job from a path that can be torn down"
  fail=1
else
  want=$(cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array><string>/bin/zsh</string><string>$repo/bin/reindex.sh</string></array>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>$HOME/.asdf/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
  <key>StartInterval</key><integer>900</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/agent-memory-reindex.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/agent-memory-reindex.log</string>
</dict>
</plist>
PLIST
)
  if [ -f "$plist" ] && [ "$(cat "$plist")" = "$want" ] && launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
    say "  $label already scheduled"
  elif [ $dry -eq 1 ]; then
    say "  would write $plist and load it"
  else
    launchctl bootout "gui/$(id -u)/$label" 2>/dev/null
    print -r -- "$want" > "$plist" \
      && launchctl bootstrap "gui/$(id -u)" "$plist" \
      && say "  scheduled $label every 15 minutes" \
      || { say "  could not load $plist"; fail=1 }
  fi
fi

say ""
if [ $fail -ne 0 ]; then
  print -u2 "install completed WITH FAILURES — see FAILED lines above"
  exit 1
fi
[ $dry -eq 1 ] && say "dry run only. --dry-run cannot detect a broken PATH or a failed exec; re-run without it to install."
exit 0
