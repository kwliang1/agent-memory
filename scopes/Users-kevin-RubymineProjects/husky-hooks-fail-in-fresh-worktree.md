---
name: husky-hooks-fail-in-fresh-worktree
description: "A fresh worktree has no .husky/_/husky.sh (gitignored, generated) and no node_modules, so every git commit AND git push dies before running any check — read the hook, run its checks by hand, then --no-verify"
metadata:
  node_type: memory
  type: reference
  originSessionId: 6a16a573-0d6f-46b0-926a-158d11ceeb46
  modified: 2026-09-25T23:47:26.920Z
---

`.husky/.gitignore` contains `_`, so **`.husky/_/husky.sh` is a generated artifact that no worktree
gets**. Both hooks start with `. "$(dirname "$0")/_/husky.sh"`, so in a fresh worktree they fail on
line 2 — before running a single check:

```
.husky/pre-commit: line 2: .husky/_/husky.sh: No such file or directory
```

Graphite surfaces it as `ERROR: pre-push git hook failed while pushing branches <branch>`, which
reads like a Graphite problem. It is not.

**Do not "fix" it by running `pnpm install` in the worktree.** venture's pre-commit runs
`pnpm lint-staged`, whose `*.{rb,rake}` entry is `rubocop --autocorrect …` — the exact thing
`AGENTS.md` warns sweeps unrelated pre-existing offenses into your diff. On VENTURE-VK4 it would
have flipped an untouched `# typed: false` → `true` in a spec I was only appending to.

**Do this instead** — read both hooks, run what they actually check, then bypass that hook only:

- **pre-commit** (venture): two checks. (1) refuses staged legacy `*.graphql` outside an exclude
  list; (2) `pnpm lint-staged`. Reproduce by hand:
  `git diff --cached --name-only '*.graphql' | wc -l` and
  `bundle exec rubocop --fail-level error --force-exclusion -f s --display-only-fail-level-offenses <staged .rb>`.
- **pre-push** (venture): only guards against pushing `main`. On any other branch it is `exit 0`,
  so there is genuinely nothing to reproduce.

Then `git commit --no-verify` / `git push --no-verify`. **`--no-verify` does not touch signing** —
`commit.gpgsign` still applies, so this does not violate the never-disable-signing rule. Say in the
report that you bypassed the hook and which checks you ran by hand.

`gt submit` has no `--no-verify` passthrough; push with `git push --no-verify -u origin <branch>`
first, then `gh pr create`. See [[shared-checkout-worktree-isolation]] and
[[another-session-can-tear-down-your-worktree]] for the other worktree traps.
