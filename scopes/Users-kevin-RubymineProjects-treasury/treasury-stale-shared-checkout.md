---
name: treasury-stale-shared-checkout
description: "The shared /Users/kevin/RubymineProjects/treasury checkout runs weeks behind origin/main — never read code facts from it"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 134e0e7c-dbe0-4de8-9e88-c2263b785ac4
  modified: 2026-09-02T22:53:05.332Z
---

The shared checkout at `/Users/kevin/RubymineProjects/treasury` is a parking spot for worktrees, not a current tree. On 2026-09-02 it sat at `891e64b60` (Aug 22) while `origin/main` was `518f4b1c4` — 11 days and dozens of commits behind. Same trap for a GitHub permalink pinned to an old sha.

**Why:** I read `cdk8s/schedule.ts`, `adapters/base.rb` and `db/schema.rb` from it and reported three things to Kevin that were false on current main: that the cron still lived in cdk8s (it had moved to the Temporal registry), that `fetch_yield_events` was missing from the adapter interface (added 2026-07-22, #8071), and that no provider-neutral dedup key existed (`idx_mmf_yields_on_account_accrued_amount` shipped 2026-07-01, #8040). Two Linear issues were filed on those false premises and had to be rewritten. I also built an objection to Kevin's plan on the missing-key claim and had to withdraw it — he was right and I was arguing from stale code.

**How to apply:** before citing any treasury `file:line`, `git fetch origin main` and read from a worktree created off `origin/main`, or `git show origin/main:<path>`. Cheap check: `git -C <checkout> log -1 --format='%h %ad' --date=short` against `git ls-remote origin main`. Same discipline for a user-supplied GitHub blob link — the sha in the URL is where *they* were looking, not where main is. Related: [[shared-checkout-worktree-isolation]], [[bash-cwd-persists-across-calls]], [[treasury-cron-schedules-cdk8s]].
