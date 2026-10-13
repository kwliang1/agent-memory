---
name: feedback-nova-worktree-use-the-skill
description: "When Kevin asks for a worktree in nova, always use the worktree-dev skill and a full `just worktree-init` — never a bare `git worktree add`"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0175bc4e-ff44-4eb8-b247-0f15f49ed620
  modified: 2026-09-10T20:50:17.063Z
---

Said 2026-09-10: "full worktree-init. whenever I ask for a work tree in this repo, make sure to
use that skill (persist it)."

The skill is `worktree-dev`, a nova project skill at `nova/.claude/skills/worktree-dev/`. It drives
`just worktree-init [-n <name>] [-b <branch>]` → `scripts/worktree/init.sh` (`justfile:548-551`).
Teardown is `just worktree-teardown <name> [-r]`.

**Why:** a bare `git worktree add` plus hand-copied `.npmrc`/`.devcontainer/.env` gets code
compiling but leaves the worktree with no isolated DB, no allocated ports, and no
`.worktree-context.md` — so the branch ends up running against the main checkout's dev environment
and any seed script's writes land in the setup Kevin works in daily. He'd rather pay the isolation
cost than have a session mutate his main dev DB.

**How to apply:** on any "give me a worktree" / "spin up a worktree" request for nova, invoke the
`worktree-dev` skill first and run the full init. Do not offer "run this branch on main's env" as
the cheap alternative — he already rejected it once. Known risk to surface, not to route around:
`scripts/worktree/ports.sh` gives up after 50 attempts at a free offset, and there are ~28
worktrees live.

**Why I missed it again (2026-09-28, third correction):** `.claude/skills/worktree-dev/` is
**untracked** — it exists only in `~/RubymineProjects/nova`, not on `origin/main`. A worktree cut
from `origin/main` therefore has no `worktree-dev` in its own `.claude/skills/`, and a session whose
cwd is not the main nova checkout never sees the skill listed at all. So the reminder does not
arrive on its own: check `/Users/kevin/RubymineProjects/nova/.claude/skills/worktree-dev/SKILL.md`
by absolute path. Also `just worktree-init -b <branch>` always creates the branch — it fails with
`fatal: a branch named '<x>' already exists` if you pre-made one, so let init create it, or delete
yours first (save the diff to a patch outside the worktree before you do).

**`worktree-init` branches from the MAIN CHECKOUT'S HEAD, not `origin/main`.** On 2026-09-28 it
gave me a worktree at `4cc653e0a7` (Sep 15) while `origin/main` was `50b6c7b286` (Sep 28), so a
patch built against current main would not apply and the files I needed did not exist yet. Fix in
place — the provisioning is all untracked, so `git fetch origin main && git reset --hard
origin/main` inside the worktree keeps `.worktree-context.md`, `.devcontainer/.env.worktree` and
every `*/node_modules`. Do it right after init and before writing any code. The worktree lands at
`nova/.worktrees/<name>/`, not `nova-worktrees/<name>/`.

Narrow exception, still valid: [[nova-worktree-lightweight-verify]] — a plain `git worktree add`
is fine for a throwaway tsc/unit-test verification that Kevin did not ask for a worktree for.

See [[build-wt-worktree-targets]] for the spawn-side path, and
[[spawned-session-crash-recovery]] — a respawn can mass-delete a worktree's tracked files.
