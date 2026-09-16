---
name: build-wt-worktree-targets
description: "The `build-wt` spawn flow only accepts registered worktree targets — treasury, venture, nova. hydra (and others) are NOT registered and fail to spawn a worktree."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0e543ade-488f-42be-95ee-8849ec3b5a75
---

`mcp__plugin_discord_discord__spawn_session` with the `worktree` param only accepts **registered** repos: **treasury, venture, nova**. Passing an unregistered repo (e.g. `hydra`) fails: *"worktree target '<x>' is not a git repo … treasury/venture/nova are worktree targets."*

So a `build-wt: <repo>` directive for a repo outside that set can't auto-create an isolated worktree. Fallbacks: (1) Kevin registers the repo as a worktree target, (2) manually `git worktree add` + spawn a plain session pointed at it, or (3) spawn a plain session on the main checkout (no isolation — risky for large rebases / for hydra which is the bridge's own substrate).

Note: `hydra` is the bridge tooling that runs these Russell sessions (daemon + Slack/Discord gateway); local remotes there are `origin` = sf8193/hydra (upstream), `fork` = kwliang1/hydra (Kevin's fork).

**RESOLVED 2026-07-07 — there is NO allowlist.** `build.ts`/`session-lifecycle.ts` do `repoDir = resolve(SPAWN_CWD, worktreeTarget)` then check it's a git repo — ANY git repo under `SPAWN_CWD` works (hydra included). The real bug was a malformed `SPAWN_CWD` in `/Users/kevin/.claude/channels/slack/.env`: an **inline `# comment` on the value line** that the daemon's `.env` loader didn't strip, so `SPAWN_CWD` = `/Users/kevin/RubymineProjects        # so treasury/venture/nova are worktree targets`. This broke BOTH worktree resolution AND every spawn's `cd` → sessions crash-looped (`spark→pulse→spark`, "crash detected"). Fix: moved the inline comments to their own lines in that `.env` (robust to bash-source AND dotenv parsers), then **restarted the daemon** (`hydra/restart-daemon.sh`, or `hydra restart slack`) — config changes need a daemon restart to take effect. Underlying code bug still open: the daemon `.env` loader should strip inline comments (the voice-dictation PR kwliang1/hydra#1 already does this for the sidecar `.env`).
**2026-09-10 — `spawn_session` MCP tool can wedge while the daemon is HEALTHY; fall back to the hydra CLI.** `spawn_session` (and `reply`) went silent for 1800s and the harness aborted the task. Meanwhile `bun cli/hydra.ts health` answered instantly (15 sessions, tmux running) and the daemon kept emitting vitals — so the break was **this session's MCP shim**, not hydra. Don't restart the daemon to fix it when other sessions are live (disruptive); Kevin restarting the MCP process on his side has revived `reply` before.

Working fallback for a worktree spawn:
1. `git worktree add -b kevinliang/<branch> /Users/kevin/RubymineProjects/.worktrees/nova-<name> origin/main` (hydra's own convention is that parent-level dir, symlinked into `nova/.worktrees/`).
2. Copy the gitignored `.npmrc` + `.devcontainer/.env` from the main checkout in yourself — the CLI path does no worktree setup.
3. `cd /Users/kevin/RubymineProjects/hydra && env -u CLAUDE_CONFIG_DIR bun cli/hydra.ts spawn "$PROMPT" --initiator "session:byte" --idempotency-key "<key>" --model opus`
Gotchas: **`hydra spawn` has NO `--worktree` flag** (grep confirms only `helpers.ts`/`lifecycle.ts` mention worktrees, for SPAWN_CWD validation) — so the spawned session's cwd is SPAWN_CWD, NOT your worktree. You MUST pin it in the prompt to absolute paths + `git -C <abs>` or it will edit the main checkout. `hydra` is a shell ALIAS (`bun .../cli/hydra.ts`), so `env -u CLAUDE_CONFIG_DIR hydra …` fails with "No such file or directory" — invoke bun directly. `--initiator` and `--idempotency-key` are both REQUIRED. Exit 2 = idempotency hit, not an error. See [[bridge-outbound-dead-curl-fallback]], [[hydra-cli]] skill, [[daemon-restart-via-bash-not-cli]].
