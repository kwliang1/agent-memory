---
name: hydra-daemon-bun-shadowed-by-dot-bun
description: "The hydra daemon can run a DIFFERENT bun than Kevin's shell — helpers.ts prepends ~/.bun/bin, and `bun upgrade` only replaces the binary it runs from, so an orphaned ~/.bun/bin/bun silently pins the daemon to an ancient version."
metadata:
  node_type: memory
  type: project
---

**Resolved 2026-09-14.** Daemon was running bun **1.2.22** while Kevin's terminal ran **1.4.2**. Two separate bun installs; `bun upgrade` never bridges them.

**Mechanism**
- `cli/helpers.ts:47-59` (`resolveConfig`) prepends `extraPaths` to the daemon's PATH. The list includes `~/.bun/bin` (line 51) *after* `~/.asdf/shims` — but the filter is `missing = extraPaths.filter(p => !currentPath.includes(p))`, so **entries already on PATH keep their existing (late) position while missing ones leap to the front.** `.asdf/shims` was already present → stayed at position 8; `.bun/bin` was missing → jumped to position 2. The intended lower-priority entry wins.
- `~/.bun/bin/bun` was an orphaned standalone install from Sep 2025 (1.2.22) that no shell ever ran.
- `bun upgrade` replaces **only the binary it is currently executing**. Kevin's shell resolves via `~/.asdf/shims/bun`, so upgrades landed in `~/.asdf/installs/bun/<ver>/bin/bun` and never touched `~/.bun/bin`.
- The launcher bakes a literal `PATH='...'` into the tmux command line, so **restarting can never change it** — only the code or the filesystem can.

**Fix applied:** `mv ~/.bun/bin/bun ~/.bun/bin/bun.1.2.22.orphan`, then restart. `~/.bun/bin` was otherwise empty (only bun-global package is `@types/bun`, no executables), so the daemon falls through to asdf. **Keep `helpers.ts:51`** — that line legitimately exposes `bun install -g` CLI tools to the daemon; it only misfired because a stale `bun` sat in the dir.

**Diagnostics that work**
- `lsof -p <daemon-pid> | awk '$4=="txt"{print $NF}'` — the actual executable image. Survives a rename (macOS keeps the inode), so a running process will report the *new* name while still executing old code.
- Simulate the daemon's PATH rather than trusting your own: `env -i PATH="<daemon PATH>" HOME=$HOME /usr/bin/which bun`.
- **Do NOT use** `ps eww <pid> | tr ' ' '\n' | grep -m1 '^PATH='` — it splits on the space in `Library/Application Support` and shows a PATH that looks truncated but isn't.

**Leftover:** `bun upgrade` wrote into asdf's install tree behind its back, so `~/.asdf/installs/bun/1.3.14/` now contains 1.4.2 and both `asdf current bun` and `.tool-versions` report a version that isn't there. Clean version is `asdf install bun 1.4.2` + repoint `.tool-versions` + reshim. See [[daemon-restart-via-bash-not-cli]].
