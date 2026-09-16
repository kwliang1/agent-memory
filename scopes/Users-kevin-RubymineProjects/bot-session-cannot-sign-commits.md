---
name: bot-session-cannot-sign-commits
description: "SSH signing from this bot/bridge session is INTERMITTENT — it failed 2026-07-23 but succeeded 2026-07-27. Always verify, never assume either way."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bdbca3ad-4975-477d-bbfc-78f15a58c406
  modified: 2026-07-28T07:54:36.982Z
---

**UPDATE 2026-07-27: signing WORKED from this bridge session.** Committing with an explicit
`git -c gpg.format=ssh -c gpg.ssh.program="/Applications/1Password.app/Contents/MacOS/op-ssh-sign" commit -S`
produced signed commits on both treasury `kevinliang/bank-1506` (PR #8375) and venture (PR #31974); GitHub reported `verification.verified = true, reason = valid` for both. So this is **not** an absolute structural barrier — it depends on whether 1Password is unlocked and reachable at the time.

Worked again 2026-07-28 (treasury PR #8377, ~8 successive `--amend -S` in a worktree, all `gpgsig`, GitHub `verified=true`) — with `git -c gpg.format=ssh -c commit.gpgsign=true commit --no-verify -S`. Two successes in a row now; treat working-when-1Password-is-unlocked as the expected case.

**How to apply now:** attempt the signed commit, then *verify* rather than assume — `git cat-file commit HEAD | grep -c gpgsig` locally, and `gh api repos/{owner}/{repo}/commits/{branch} --jq '.commit.verification.verified'` after push. Only fall back to the "flag it to Kevin / he re-signs" path below if verification actually fails. The original failure analysis follows and still explains what happens when it does fail.

---

When I build a PR from this bot/bridge session, `git commit -S` produces an **unsigned** commit (`git log -1 --format='%G?'` → `N`), even though `commit.gpgsign=true`, `gpg.format=ssh`, `user.signingkey`, and `gpg.ssh.program=…/op-ssh-sign` are all set and `SSH_AUTH_SOCK` points at a live 1Password agent socket (`ssh-add -l` even lists the key).

**Confirmed mechanism (2026-07-23, PR #8332):** git DOES invoke `/Applications/1Password.app/Contents/MacOS/op-ssh-sign` (verified via `GIT_TRACE=1`), but that helper can only raise the 1Password approval UI inside Kevin's **GUI/login session**. This bot shell is detached from that session, so the prompt never reaches his screen ("I don't see it") and op-ssh-sign returns without a signature — git proceeds and the commit is unsigned, no error. Retrying, longer timeouts, and `git rebase --gpg-sign` (a no-op when already at tip) do NOT help. There is nothing I can do from here to get the signature — it is a structural barrier, not a timing/approval-window issue.

**Why:** branch protection on treasury (and peers) enforces *verified signatures at merge*, so an unsigned commit pushes fine and CI runs, but **cannot merge** until re-signed. Never fix this by disabling signing (`commit.gpgsign=false` / `-c commit.gpgsign=false`) — that's a hard no.

**How to apply:**
- Push + open the PR anyway (signature is enforced at merge, not push) so CI/review proceed.
- **Flag the unsigned state to Kevin up front** — don't let it surprise at merge time. Do NOT offer to "trigger the prompt" so he can approve — it won't reach him; only he can sign, from his own terminal.
- Re-sign is Kevin's to run **in his own interactive terminal** (where 1Password can prompt): `git commit --amend --no-edit -S --no-verify && git push --force-with-lease` from the branch's worktree (`--no-verify` because husky is broken in worktrees). `git rebase --gpg-sign origin/main` alone is a no-op when the branch is already at tip — use `--amend` or `rebase -f` to force re-signing.
- Related: [[onepassword-cli-prompts]] (OP_SERVICE_ACCOUNT_TOKEN kills `op` CLI prompts but does NOT solve SSH commit signing), [[shared-checkout-worktree-isolation]].

**`git log --show-signature` lies about this locally (2026-09-11, nova PR #9989).** After a `gt modify -a` amend I read `git log --format='%G?'` → `N` and `--show-signature` → `No signature`, and briefly reported the commit as unsigned. Both were wrong: the output was preceded by `error: gpg.ssh.allowedSignersFile needs to be configured and exist for ssh signature verification`. Without that file git cannot *verify* an SSH signature, so it reports absence rather than "unverifiable" — a false negative, not a missing signature. `git cat-file commit HEAD | grep -c gpgsig` returned 1 and GitHub returned `verified: true, reason: valid`.

So the verification order in "How to apply" above is load-bearing and should be followed exactly: **check the `gpgsig` header first, then GitHub — never `%G?` or `--show-signature`** on this machine. Trusting them sends you chasing a signing failure that isn't there, and the tempting "fix" is the one hard-forbidden action (disabling signing).
