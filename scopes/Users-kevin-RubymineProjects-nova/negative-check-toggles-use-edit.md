---
name: negative-check-toggles-use-edit
description: "When temporarily reverting one fix to prove a test is load-bearing, toggle it with the Edit tool (unique old_string), never sed — a shared pattern silently clobbers other call sites."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9bc97e97-764e-47f9-ac44-d3459c01a56c
  modified: 2026-09-02T22:45:43.923Z
---

Proving a fix is load-bearing (revert it, watch the test fail, restore) is worth doing — but do the toggle with `Edit` on a unique `old_string`, never `sed -i` on a short pattern.

**Why:** On BANK-1943 (2026-09-02) the restore `sed 's|idempotencyKey: resolveKey(args) }|...|'` matched a *second* site (`handleAlreadyCommitted`'s `findCommitIdempotency` lookup) and rewrote it to look up a random uuid, so three unrelated conflict-detection tests started reading `ALREADY_COMMITTED`. It cost a DB forensics round before `git diff` showed it.

**How to apply:** after any toggle round-trip, `git diff` the file and confirm the only hunks are the intended ones before trusting a test result. If a bulk toggle is unavoidable, `grep -c` the pattern first and expect exactly 1. See [[spawned-nova-worktree-is-bare]] for the rest of the spawned-session test workflow.

**Turbo caches the negative check and reports a FALSE PASS (BANK-2029, 2026-09-17).** A toggle round
trip is worthless through `just tt`: after deleting a singular/plural ternary the app suite reported
`37 passed` twice, and only `just turbo test:staged --filter=app --only --force -- --passWithNoTests
<file>` gave the honest red. This bit three times in one session, and a reviewer hit it
independently. **Every negative check in nova must pass `--force`** (graph is safe run directly via
`pnpm -C graph test <file>` with `.devcontainer/.env` sourced, which does not go through turbo).

Corollary worth the same weight: a negative check only proves what you mutate. Deleting a
"redundant" test can remove the *only* fixture that distinguishes two fields — on BANK-2029,
dropping one balance test left `availableBalance <- totalBalance`, `cashBalance <- availableBalance`
and `cashBalance <- totalBalanceEndOfLastMonth` all green, because every surviving fixture set the
three amounts equal. Make fixture values deliberately distinct, and re-run the mutation set after
deleting any test.

**Do not restructure branches while a mutation-testing agent is running (BANK-2029, 2026-09-17).**
A reviewer permitted to temporarily mutate source restores with `git checkout HEAD -- <file>`. I
split a combined branch into a BE/FE stack mid-round, switching branches twice underneath it — so
`HEAD` meant a different commit at restore time than at mutation time. On the BE branch the app
files sit at base, so a restore there would have silently reverted the FE work. It happened to come
out clean (both branches verified content-identical to the reviewed commit), but the safe order is:
let the round finish, then restructure. Two reviewers also independently flagged that the worktree
had moved under them — treat that report as a correctness signal about your own process, not noise.
