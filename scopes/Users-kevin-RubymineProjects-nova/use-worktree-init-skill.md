---
name: use-worktree-init-skill
description: "In the nova repo, always use the worktree-init skill for worktree setup — never hand-roll provisioning or copy env files manually."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 735720e2-1046-4f41-a5f3-9c7683877ee2
  modified: 2026-09-10T14:56:18.649Z
---

Whenever Kevin asks for a worktree in the nova repo, use the `worktree-init` skill. Stated 2026-09-10 as a standing preference ("whenever I ask for a work tree in this repo, make sure to use that skill").

**Why:** hand-rolling provisioning (copying `.npmrc` + `.devcontainer/.env` from the main checkout to get things compiling) produces a half-provisioned worktree — no `.worktree-context.md`, no dedicated DB, no allocated ports, no docker containers. It compiles and tests, so the gap stays invisible until you need to actually run the app, and then the setup has to be redone properly anyway.

**How to apply:** reach for the skill at the START of worktree work, not after discovering the shortcut was insufficient. Prefer it even when port pressure makes allocation look likely to fail (~28 worktrees / ~87 listening ports on this machine) — Kevin chose full init over the fast path even knowing `scripts/worktree/ports.sh` gives up after 50 attempts.

See [[spawned-nova-worktree-is-bare]] for what a spawned worktree is missing and the symlink trap when provisioning one in place.
