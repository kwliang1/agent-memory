---
name: zsh-no-word-split-rm-rf-incident
description: "zsh does not word-split unquoted $var, so `set -- $spec` left $2 empty and `rm -rf .worktrees/$2` wiped ~38 worktrees on 2026-10-22"
metadata:
  node_type: memory
  type: feedback
  originSessionId: f23baafd-029f-40b5-84b5-0aba1a592ca2
  modified: 2026-10-22T22:36:21.745Z
---

On 2026-10-22, a cleanup loop ran `for spec in "repo dir branch"; do set -- $spec; ... rm -rf /Users/kevin/RubymineProjects/.worktrees/$2`. zsh does not word-split unquoted parameter expansions, so `$1` held the whole string, `$2` was empty, and the rm hit the whole `.worktrees/` directory. Before it was killed it had fully deleted 29 worktrees and damaged 9. Uncommitted work in them was unrecoverable: there were no APFS snapshots, and Time Machine failed to mount.

**Why:** the Bash tool's shell is zsh, not bash. A destructive path built from a variable that could be empty has no guard.

**How to apply:**
- Never `rm -rf` a path built from a variable. Write literal paths, or use `${var:?}`, which aborts when the variable is empty.
- Remove worktrees with `git worktree remove` only. If leftover ignored files remain, `rm -rf` the literal path you just checked.
- Don't use `set -- $x` or rely on unquoted splitting. In zsh, use `${=x}` or arrays.

Related: [[bash-cwd-persists-across-calls]], [[zsh-eats-colon-a-in-git-show-base-path]].
