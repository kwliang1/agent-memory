---
name: stale-shared-checkouts-are-the-norm
description: "Every shared checkout under ~/RubymineProjects runs days-to-weeks behind origin/main — nova burned me the same way treasury did; fetch and cite origin/main, never the working tree"
metadata:
  node_type: memory
  type: feedback
  originSessionId: bfbfc010-962b-4802-bea2-e4aa41025e28
  modified: 2026-09-28T19:34:31.000Z
---

The staleness trap is not treasury-specific. On 2026-09-28 I answered a nova question from
`~/RubymineProjects/nova`, which sat at `4cc653e0a7` (Sep 15) while `origin/main` was `50b6c7b286`
(Sep 28) — 13 days and, critically, **dirty** (uncommitted modifications on `main`).

**What it cost:** I told Kevin nova's account balance card derived its Pending figure as
`totalBalance − availableBalance` off the Prophet `CustomerAccount::Balance` endpoint, citing
`EntityFinancialAccountBalanceCard.tsx:63`. PR #10205 (merged 2026-09-23) had already replaced that
with a `Processing` stat sourced from nova's own `pendingTransfers`, so the endpoint no longer feeds
it at all. Kevin caught it with "are you certain this is the endpoint nova hits today?" — I had
built a whole treasury-side change on the stale reading. The conclusion survived, but the target
moved, and he had to be the one to check.

**How to apply:** before citing any `file:line` in ANY repo under `~/RubymineProjects`, run
`git fetch origin main -q` then compare `git log -1 --format='%h %ad' --date=short HEAD` against
`origin/main`. Read with `git show 'origin/main:<path>'`, not `cat`/`sed` on the working tree. Also
check `git status --porcelain` — a shared checkout sitting dirty on `main` means even the tracked
content may not be any committed state. When a finding turns on how a consumer behaves *today*,
`git log origin/main --oneline -5 -- <path>` on the specific file is the cheap confirmation, and the
commit it names is what to quote back. Same discipline for a GitHub permalink: the sha in the URL is
where the other person was looking, not where main is.

Related: [[shared-checkout-worktree-isolation]], [[bash-cwd-persists-across-calls]],
[[feedback_use_worktree_for_other_branches]]. The treasury-scoped version of this is
`treasury-stale-shared-checkout` in the treasury scope — this note generalises it to every repo.
