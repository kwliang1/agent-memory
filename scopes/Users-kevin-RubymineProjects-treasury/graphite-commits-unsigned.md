---
name: graphite-commits-unsigned
description: gt modify/create produces UNSIGNED commits even with commit.gpgsign=true; how to re-sign
metadata: 
  node_type: memory
  type: reference
  originSessionId: d0822b92-ae48-4800-8624-a9ee10c0cbae
  modified: 2026-08-06T22:28:14.944Z
---

`gt modify -c` / `gt commit create` (Graphite) create commits that are **unsigned** even when `git config commit.gpgsign=true` (1Password SSH signing via `gpg.ssh.program=op-ssh-sign`). Branch protection on `angellist/treasury` requires verified signatures, so unsigned commits block merge.

Re-sign an already-committed HEAD without re-running the `git commit`-matching pre-commit hook:
```
git rebase -f --gpg-sign main   # -f forces replay even when "up to date"; plain `git rebase --gpg-sign main` is a no-op and does NOT re-sign
```
(1Password must be unlocked to authorize the signer.)

Verifying locally is misleading: `git log %G?` returns `N` and `--show-signature` says "No signature" because no `gpg.ssh.allowedSignersFile` is configured — this is a *local verification* gap, NOT proof the commit is unsigned. Check the truth two ways:
- `git cat-file commit HEAD | head` — a `gpgsig -----BEGIN SSH SIGNATURE-----` header means it IS signed.
- Confirm GOOD with a temp signers file: `S=$(mktemp); echo "kevin.liang@angellist.com $(git config user.signingkey)" > $S; git -c gpg.ssh.allowedSignersFile=$S log -1 --show-signature` → "Good git signature".
- After push: `gh api repos/angellist/treasury/commits/<sha> --jq .commit.verification` → `{"verified":true,"reason":"valid"}`.
