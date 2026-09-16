---
name: spawned-session-crash-recovery
description: "After a spawned-session process crash/restart (e.g. spend-limit 429): background shells lose cwd + sandbox path visibility, and the worktree's tracked files can be mass-deleted — git restore recovers."
metadata: 
  node_type: memory
  type: project
  originSessionId: 6c337ba4-0475-45ef-b6cb-7727fa332a3e
  modified: 2026-08-28T06:54:11.053Z
---

Observed 2026-08-28 (cedar, BANK-1885) when the account spend limit killed the process mid-task:

1. **Worktree gutted:** on restart, 3,451 tracked files were deleted from the working tree (justfile, app/, dotfiles) while commits, untracked files (node_modules, .devcontainer/.env, graph/schema.graphql) survived — EXCEPT `app/gen` which was also gone. Recovery: `git -C <worktree> restore .` + `pnpm codegen` in app + `pnpm install --frozen-lockfile` sanity check. Never assume the branch is lost — check `git log` first.

**Why:** and 2. **Background Bash changes behavior after restart:** backgrounded commands start in the ORIGINAL project cwd (not the shell's persisted cwd) and the sandbox could not see `/Users/kevin/RubymineProjects/.worktrees/*` ("No such file or directory" for files that exist). Foreground shells were fine.

**How to apply:** after any spawned-session restart, immediately (a) `git status` the worktree and restore deletions, (b) regenerate gitignored codegen, (c) restart `just dev up` — use `just --justfile <abs> --working-directory <abs>` with `dangerouslyDisableSandbox: true` for backgrounded runs, (d) resume interrupted subagents via SendMessage (their transcripts survive).

**2026-09-10 — the trigger is not always a crash. A Claude Code auto-update does it too.** Two
sessions (`ember`, `pixel`) were killed ~3 min apart with identical ~3,500-file worktree wipes. No
crash, no spend limit, no OOM: the old session logged `✔ Update installed · Restart to update`, and
`~/.local/bin/claude` was verified re-symlinked to `versions/2.1.268` at 13:48 local — the same
minute the restart fired. The destructive part is hydra's restart, not the update.

Also true here: `pnpm install --frozen-lockfile` FAILS on an autoInstallPeers lockfile mismatch —
use `pnpm install --no-frozen-lockfile` (48s, exit 0).

**The dangerous minute is right after respawn.** A `gt modify -a` or `git commit -a` before
`git restore .` commits the ~3,500 deletions straight into the open PR. Always `git status` first;
never use `-a` in a freshly respawned worktree.

**A respawn can come back pointed at the WRONG worktree — check cwd before the file wipe.** 2026-09-10: `pixel`, whose worktree is `.worktrees/nova-pixel` (`kevinliang/bank-2004`), respawned with its primary working directory reported as `nova-worktrees/wt-mm-comment` — an unrelated stale worktree on the long-merged `kevinliang/enable-matchmaking-scoring-prod` (#9833). It caught this before running anything and used `git -C <abs>` throughout, so nothing was polluted (that worktree verified 0 changed files afterwards). But a build or commit there would have written to the wrong branch entirely. So the post-respawn checklist starts one step earlier than "restore the wipe": **first confirm which directory you actually came back in**, then `git -C <intended-abs-worktree>` for every command — never rely on the reported cwd or a bare `git`.

Order of operations after any respawn: (1) verify cwd vs the worktree you own, (2) `git status` the intended worktree and `git restore .` if it's all unstaged deletions (verify nothing is staged/modified first — then it's lossless), (3) regenerate `app/gen` + `app/node_modules`, (4) re-check the PR for bot findings that the pre-kill session fixed but never replied to. On (4): both respawns found real unreported state — a Bugbot medium that was fixed in an amend and resolved WITHOUT a reply (see [[feedback-resolve-ai-review-threads]]), and pushed work that never reached Slack before the kill. Assume the pre-kill session's Slack report is STALE, and re-derive the diff/test counts from git rather than trusting the last message.

**How to DETECT the wrong-cwd respawn (the reliable check, from `pixel` 2026-09-10).** The trap is that the harness's environment-update line reports the new cwd *authoritatively* — so landing in the wrong worktree reads exactly like the harness placed you correctly, and no amount of staring at the path reveals it. Don't reason about the path. Instead run `git branch --show-current` (or `git -C <abs> rev-parse --abbrev-ref HEAD`) and compare it against the branch named in your own thread history / task prompt. A disagreement is the signal. That check is cheaper and far more reliable than path inspection, and it's what actually caught the miss.
