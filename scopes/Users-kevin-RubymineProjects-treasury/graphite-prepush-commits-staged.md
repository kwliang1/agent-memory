---
name: graphite-prepush-commits-staged
description: "Treasury repo — a Graphite pre-push hook auto-commits any leftover STAGED files onto the current branch at push time; isolate other people's staged work before committing/pushing"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dc4cfc37-59d9-4393-bf6d-6ee6c55baf5d
---

In the treasury repo (Graphite + lefthook), pushing while unrelated files are left **staged** in the index can trigger a hook that auto-commits those staged files onto the current branch as an extra local commit. Hit 2026-07-09: Kevin had his sweep task (`book_transfer_sub_account271181_to393235`) staged-but-uncommitted on his branch; when I created a new branch and pushed my own commit, a Graphite pre-push hook committed his staged files onto my branch (local only — it did NOT reach the remote/PR, but it consumed his staged index state).

**Why:** the git index is global across branches, so another session's staged work travels with you on `checkout -b`; the hook then sweeps it into a commit. Silent — easy to bundle someone else's work or pollute a PR.

**How to apply:** before committing/pushing when the working tree has staged files you don't own: (1) commit ONLY your files by explicit path (`git commit -- <paths>`), never `-a`/`gt create -a`; (2) after pushing, verify `git rev-parse origin/<branch>` == your intended commit and `gh pr view <n> --json files` shows only your files; (3) if a stray commit appears locally, `git reset --hard <your-sha>` and preserve the other work via `git -c core.hooksPath=/dev/null cherry-pick` onto a recovery branch off `origin/main`. Disable hooks (`-c core.hooksPath=/dev/null`) on corrective commits to stop re-bundling. Relates to [[feedback-backfill-with-ledger-changes]] workflow rigor.
