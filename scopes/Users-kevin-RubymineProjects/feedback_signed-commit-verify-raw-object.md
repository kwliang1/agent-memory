---
name: signed-commit-verify-raw-object
description: "git %G? returns N (false negative) with no allowedSignersFile even when the commit IS signed — check the raw object, not %G?"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e6d2a66b-6244-4098-80fa-6b0ff02e3f83
  modified: 2026-07-22T20:52:36.704Z
---

`git log --format='%G?'` returning `N` does NOT mean the commit is unsigned. `%G?` runs *verification*, which needs `gpg.ssh.allowedSignersFile` configured locally; with 1Password SSH signing (`gpg.ssh.program=op-ssh-sign`) that file is usually absent, so `%G?` reports `N` even on a correctly-signed commit and prints `error: gpg.ssh.allowedSignersFile needs to be configured...`.

**Why:** signing and verification are independent. `op-ssh-sign` signs fine with **no Touch ID prompt** (the key is pre-authorized). The `N` is a verification gap, not a signing failure.

**How to apply:** before concluding signing failed, check the *definitive* signal, not `%G?`:
- `git cat-file -p HEAD | head -8` → look for a `gpgsig -----BEGIN SSH SIGNATURE-----` header, OR
- `gh api repos/{owner}/{repo}/commits/{sha} --jq '.commit.verification'` → `{"verified":true,"reason":"valid"}`.

Cost me a wrong "blocked on 1Password auth" report to Kevin (2026-07-22, PR #8314). `op whoami` = "not signed in" is the CLI path and is **irrelevant** to `op-ssh-sign` (app SSH integration) — don't use it to diagnose commit signing. Never disable signing to work around this (see Kevin's standing rule). Related: [[onepassword-cli-prompts]].
