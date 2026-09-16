---
name: hydra-spawn-cwd-and-memory-scope
description: "hydra has NO per-spawn cwd option: cwd is SPAWN_CWD or a worktree path. Consequence — worktree (build-wt) sessions get their own project scope with NO memory/ dir at all, so they run memory-blind."
metadata:
  node_type: project
  type: project
---

**Measured 2026-09-15.** Auto-memory is keyed to cwd (`~/.claude/projects/<cwd with / → ->/memory/`), and hydra controls cwd in only two ways.

**No cwd flag exists.** `daemon/session-lifecycle.ts:566` — `let effectiveCwd = spawnCwd` (`process.env.SPAWN_CWD`, required at :560). Reassigned in exactly two places:
- `:582` `effectiveCwd = reuseWorktree.path` (recovery)
- `:598` `effectiveCwd = wt.worktreePath` (worktree spawn)

There is no `opts.cwd` in `doSpawnSession`. SPAWN_CWD is daemon-level env baked into the tmux command line, so changing it is global to every spawn.

**A worktree spawn's cwd is NOT the repo.** `worktree-manager.ts:88`: `wtDir = resolve(repoDir, '..', '.worktrees', dirSuffix)` with `dirSuffix = ${worktreeTarget}-${tmuxName}` (`session-lifecycle.ts:589`). So a nova worktree lands at `/Users/kevin/RubymineProjects/.worktrees/nova-jade` — umbrella level, not inside `nova/`.

**The memory scopes, measured:**

```
-Users-kevin-RubymineProjects              224 files   84 entries   25103B   ← plain spawns
-Users-kevin-RubymineProjects-nova          46 files   27 entries    9386B   ← unreachable by any spawn
-Users-kevin-RubymineProjects-treasury      87 files   13 entries    3165B   ← unreachable by any spawn
-Users-kevin-RubymineProjects--worktrees-*   0 files   NO MEMORY.md          ← all 39 worktree scopes
```

**So `build-wt` sessions run memory-blind** — not "wrong index", *no* index. And the per-repo indexes are reachable by no hydra spawn path. Compressing the umbrella `MEMORY.md` helps plain spawns only; it does nothing for builders.

Corollary: memory a worktree session writes lands in a scope keyed to an ephemeral dir name (`nova-jade`); the next nova worktree gets a different name, so it's orphaned. 0 such files exist today, consistent with those sessions having no index to append to.

**ListAgents names are the cwd basename** — `nova-jade-11` ← cwd `…/.worktrees/nova-jade`; `rubymineprojects-*` ← cwd `/Users/kevin/RubymineProjects`. So the name is real evidence of a session's cwd.

Candidate fixes (none implemented, all hydra changes): thread a `cwd` opt into `doSpawnSession`; symlink each worktree project dir's `memory/` at the parent repo's; or set SPAWN_CWD per-spawn. Offered to Kevin 2026-09-15, not scoped. See [[build-wt-worktree-targets]].
