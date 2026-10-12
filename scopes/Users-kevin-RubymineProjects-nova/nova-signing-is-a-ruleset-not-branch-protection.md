---
name: nova-signing-is-a-ruleset-not-branch-protection
description: "nova requires signed commits via a repo RULESET, not classic branch protection — `branches/main/protection` reports required_signatures:false. And a commit created through the Contents API is unsigned, so it cannot merge."
metadata:
  node_type: memory
  type: reference
---

Verified 2026-09-23.

**Where the requirement lives.** `gh api repos/angellist/nova/branches/main/protection` reports
`required_signatures: false`, and the dedicated `.../protection/required_signatures` endpoint also
returns `false`. Both are misleading: the rule is in a **repo ruleset**.

```sh
gh api repos/angellist/nova/rulesets -q '.[].id' \
  | xargs -I{} gh api repos/angellist/nova/rulesets/{} \
      -q '.name + ": " + ([.rules[].type]|join(", "))'
```

The ruleset named **Default** carries `required_signatures` (plus `required_status_checks`,
`required_linear_history`, `non_fast_forward`, `deletion`, `pull_request`). "Protect default
branch" and "Only allow engineers to merge" are separate rulesets and do not.

**The trap this produced.** With no clean checkout available I created a docs commit through the
Contents API (`gh api repos/.../contents/<path> --method PUT`). It succeeded, but
`.commit.verification.verified` came back **`false`** — GitHub only web-flow-signs commits made
through the web UI, not ones pushed through the Contents API. The commit would have blocked at
merge.

**The fix that worked, and it is cheap.** A plain `git worktree add <dir> <branch>` is enough for a
markdown-only change — no `just worktree-init`, no infra, no `pnpm install`, because nothing gets
built or tested. Then `git commit --amend --no-edit --no-verify` re-signs it locally (1Password
SSH), `git push --force-with-lease`, and `git worktree remove --force` afterwards. Confirm with
`gh api repos/angellist/nova/commits/<sha> -q '.commit.verification.verified'`, not `%G?` — see
[[git-ssh-sig-reads-as-unsigned]] for why the local check lies.

One gotcha while verifying: a fresh worktree's `origin/main` ref can be far behind, so
`git diff origin/main HEAD` showed 161 unrelated files. Check the commit itself
(`git show --stat HEAD`) and its parent sha against `gh api repos/.../git/ref/heads/main`.
