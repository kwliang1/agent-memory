---
name: git-ssh-sig-reads-as-unsigned
description: "`git log %G?` prints N (and --show-signature says 'No signature') for SSH-signed commits when gpg.ssh.allowedSignersFile is unset — the commit IS signed; check the raw gpgsig header instead"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 78274f4f-8db3-4ec3-bf9a-5c8549aba6b3
  modified: 2026-09-18T23:56:52.314Z
---

On this machine commits are SSH-signed via 1Password (`gpg.format=ssh`,
`gpg.ssh.program=/Applications/1Password.app/Contents/MacOS/op-ssh-sign`,
`commit.gpgsign=true`, all in `~/.gitconfig`). There is **no**
`gpg.ssh.allowedSignersFile` configured.

Consequence: git cannot verify its own SSH signatures, and it reports that as
**absence**, not as unverifiable —

- `git log --format='%G?'` prints `N` ("no signature")
- `git log --show-signature` prints `No signature` plus
  `error: gpg.ssh.allowedSignersFile needs to be configured and exist for ssh signature verification`

Both readings are wrong. Verify with the raw object instead — a signed commit has a
`gpgsig` header:

```
git cat-file commit HEAD | sed -n '1,8p'    # look for a `gpgsig -----BEGIN SSH SIGNATURE-----` line
```

Contrast: commits merged by GitHub are **PGP**-signed and show `E` ("cannot check"),
so a `git log --format='%G?'` over a branch shows `E` for main's commits and `N` for
your own — which looks exactly like "mine are unsigned" and is not.

**Why this matters:** CLAUDE.md forbids ever disabling commit signing, and branch
protection requires verified signatures. A false `N` invites "fixing" signing that was
never broken — re-signing rebases, or worse, config edits. Check `git cat-file` before
concluding anything is unsigned. Observed 2026-09-18 on `kevinliang/bank-2057`.
