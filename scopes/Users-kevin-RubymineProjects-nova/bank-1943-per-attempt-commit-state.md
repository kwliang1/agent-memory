---
name: bank-1943-per-attempt-commit-state
description: "BANK-1943 (per-attempt commit keys) SHIPPED to PR #9871 (2026-09-02): stacked on kevinliang/bank-1941 (#9830), gate passed (2 clean rounds), all round-6 opens fixed; design decisions + review-found invariants."
metadata: 
  node_type: memory
  type: project
  originSessionId: 91d1c372-a168-411a-b4bd-2e7543b4afab
  modified: 2026-09-03T01:28:58.348Z
---

**State (2026-09-02, session haze):** PR https://github.com/angellist/nova/pull/9871, branch `kevinliang/bank-1943` @ `2af65c4a0f`, base `kevinliang/bank-1941` (#9830 — must merge first; rebase 1943 onto main if 9830 lands squashed). Review gate PASSED: 6 rounds total, rounds 5+6 clean (round 6 = fresh Fable reviewers). comet's stranded commit `13afb89c9f` recovered via shared worktree object store; salvage ref `bank-1943-salvage` in nova-haze can be deleted after merge. Worktree nova-haze provisioned stack-free (nova_haze_test on main's postgres).

**Everything from comet's round-6 backlog was fixed on top of its diff:**
- `executePort` returns `ownerGranted`; a dedup port binds OWNERLESS content (`portedContentHash` chosen in runPort) so owner-asserting replays read IDEMPOTENCY_CONFLICT, never false ALREADY_COMMITTED (test 43j).
- `stampCommitted` sources the binding write from durable context (`portedIdempotencyKey`/`portedContentHash` on the `committed` payload → `rememberPortResult`), not the in-memory plan — restart re-run safe.
- `settleCommit`'s `hasUnprocessedEvents` query is gated on `peekPortPlan(attemptId) !== undefined`.

**Gate-round finds (all fixed, worth remembering as invariants):**
- `reclaimLeakedPlan` drains unconditionally at `settled.status === 'COMPLETED'` — COMPLETED ⇔ final state, onEnter/sweep already ran, no outgoing edges ⇒ queued events only IGNORED (no action). Without this, an IGNORED loser whose event was still queued at settle leaked its PII plan forever.
- A FAILED binding re-assert must DROP the row's bindings (nested savepoint `drop_bindings`) — the pre-emit guard binding holds the caller's asserted hash and would fail-open a dedup port's same-owner replay. Refused upsert (0 rows, key bound to another row) gets a logger.warn.
- Vanished row projection → judge via context.matchedIpseityEntityId; bindings cascade with the row (`onDelete: Cascade`) so owner-asserting replays fail closed (43k).
- Test 43l injects a one-shot record failure via hoisted pass-through `vi.mock('data')` + `vi.hoisted` queue (plain function, immune to clearAllMocks; ESM spyOn on namespace wouldn't work).

Deploy note in PR: pre-deploy bounced rows keep old `commit:${rowId}` bindings — one-off quiesced DELETE in PR body. See [[matchmaking-owner-gate-design]], [[negative-check-toggles-use-edit]], [[spawned-nova-worktree-is-bare]].
