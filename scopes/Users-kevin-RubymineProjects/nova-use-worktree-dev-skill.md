---
name: nova-use-worktree-dev-skill
description: "For nova worktrees use the worktree-dev skill / `just worktree-init` — a bare `git worktree add` skips infra, ports and context and leaves the worktree unusable"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e77114cd-e9b9-45d6-9256-adc01111925c
  modified: 2026-09-21T20:20:52.847Z
---

When creating a nova worktree, use nova's **`worktree-dev` skill** (`nova/.claude/skills/worktree-dev`), which wraps `just worktree-init -n <name> [-b <branch>]`. Never hand-roll `git worktree add`.

**Why:** Kevin called this out directly on 2026-09-21 ("you should be using the nova worktree skill") after I created a worktree with bare `git worktree add` for a spawned build session. `scripts/worktree/init.sh` does far more than check out files:
- allocates ports and writes `.devcontainer/.env.worktree` (`PROCESS_COMPOSE_PORT`, `NOVA_APP_PORT`, `NOVA_GRAPH_PORT`)
- writes `.worktree-context.md` (services table, ports, `BASE_URL` = `https://portal-<name>.angellist.dev`)
- copies `.devcontainer/secrets`, `.lazy.nvim` and other untracked-but-required files
- provisions per-worktree postgres/temporal/typesense and `pg_restore`s `nova_<suffix>` / `capital_<suffix>`

Without it there is no running app, so any task asking for **Playwright/browser verification cannot be done at all**. That was the actual breakage, not a style nit.

**How to apply:**
- Skill is directory-scoped to nova, so it does NOT appear in the skill list when cwd is the `RubymineProjects` umbrella. Invoke it by path awareness, or run `cd <nova-root> && just worktree-init -n <name> -b <branch>` directly.
- `init.sh:94` puts worktrees at `<nova-root>/.worktrees/<name>` — note hydra spawns instead use `RubymineProjects/.worktrees/nova-<name>`. The two roots differ; `just worktree-init` run infra-only from inside an existing worktree will symlink `nova/.worktrees/<name>` → the hydra-root path to bridge them.
- `init.sh:139` refuses if the target dir already exists; run bare `just worktree-init` from *inside* an existing worktree for infra-only mode.
- Then `just dev up` (never with `-t` — TUI breaks non-interactive shells).

Related: [[hydra-worktree-add-15s-timeout]] (why I sidestepped the spawn tool in the first place), [[feedback_use_worktree_for_other_branches]].
