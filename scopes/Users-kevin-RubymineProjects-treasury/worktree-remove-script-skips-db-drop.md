---
name: worktree-remove-script-skips-db-drop
description: make clean-worktree / bin/dev/on-worktree-remove.sh prints "could not find main treasury checkout" and drops nothing; pipefail + head -1 SIGPIPE
metadata:
  type: reference
---

`bin/dev/on-worktree-remove.sh` runs under `set -euo pipefail` and finds the main checkout with `git worktree list --porcelain | head -1`. With many worktrees git gets SIGPIPE when `head` exits, the pipeline fails, and the `|| MAIN_TREASURY=""` fallback blanks it. The script then warns "could not find main treasury checkout, skipping DB cleanup", exits 0, and leaves both the databases and the `treasury-<name>` container behind (seen 2026-11-13 on atlas). The daemon's teardown calls the same script, so its cleanup is also silently skipped.

**How to apply:** copy the script to the scratchpad with the `MAIN_TREASURY=` line hardcoded to `/Users/kevin/RubymineProjects/treasury`, run it with the worktree name, then confirm with `SHOW DATABASES LIKE '%<name>%'` (mysql) and `pg_database` (postgres) from the main checkout. The real fix is `git worktree list --porcelain | sed -n '1s/^worktree //p'` (sed reads all input, so no SIGPIPE); not yet filed.
