---
name: matchmaking-select-candidate-design
description: "BANK-1923 / PR #9872 selectCandidate design decisions + three repo traps the 15-round review found (FSM per-row key dedup, ESM import-cycle TDZ, Prophet timeouts map to Unknown)."
metadata: 
  node_type: memory
  type: project
  originSessionId: 0758287e-a1be-4895-8877-a837cb960ee9
  modified: 2026-09-03T01:32:16.047Z
---

Shipped on PR #9872 (`kevinliang/bank-1923`, 2026-09-03). `adminEntityMatchmakingSelectCandidate` lets a reviewer pick one persisted candidate on a multi-candidate row.

**Design decisions (argued to a stop in review):**
- Pick edges leave `{AUTO_MATCH, NEEDS_REVIEW, CONFLICT}` and land only in `{AUTO_MATCH, NEEDS_REVIEW}`. A type-gate failure is **refused** (`TYPE_UNCONFIRMED`, nothing written) rather than parked in CONFLICT — a CONFLICT with a matched id reads as forceSyncRow's divergent-identity guard. `isTypeUnconfirmed = !typeMatched && (tinMatched || rowState === 'CONFLICT')` (no-TIN + CONFLICT ⇔ unmapped CSV type; no-TIN path never type-gates, mirrors scoring). Runs before any live read.
- No-TIN pick caps at NEEDS_REVIEW: AUTO_MATCH is what `listCommittableRowIds` sweeps unattended; design doc says a name alone never auto-matches.
- Applied-detection = look up this attempt's unique idempotencyKey in `entityMatchmakingRowFsm.query(rowId).events` (PROCESSED/IGNORED/FAILED); pick targets are non-final so execution status/resting state prove nothing. COMPLETED execution + unprocessed pick ⇒ NOT_APPLICABLE (settle returns before the drain IGNOREs).
- `commit` payload carries the decided snapshot (`decidedIpseityEntityId`, `decidedScoredAtMs`); `runPort` bounces (`needsReview`) unless row scoredAt + plan id match — checked BEFORE the review-plan branch (a denylist block gathered for a superseded pick must not park STALE).
- Ipseity `NotFound` on the picked entity → `NOT_A_CANDIDATE`; everything else → `ERRORED` at one `warn` (see trap 3).

**Three repo traps worth remembering:**
1. **FSM event keys dedup for the row's whole life** (`@@unique([workflowId, entityId, idempotencyKey])`, `emitAsync` returns `deduped:true` silently). `runPort`'s bounce emits were `needsReview:${rowId}` → a second bounce of a re-committed row was dropped and the row stranded in PENDING. Omit the key on action emits: engine default is `${eventId}:${actionName}:${entityId}:${type}`. Same class as the `reject:${rowId}:${uuid}` precedent. `commit:${rowId}` itself is still stable → BANK-1943.
2. **Import cycle TDZ under Node ESM**: `services/fsm/entityMatchmaking` → `executePort` → `data` barrel → temporal registry → `commitBatch` → `commitRow` → back. A module-level call into the FSM module from inside that cycle throws `Cannot access 'x' before initialization` when the FSM module is imported first (`tsx` reproduces it; **vitest does not**; `main.ts` survives only by import order). Keep such derivations lazy (`sourcesOf('commit')` inside a function). Probe: `graph/src/__probe.mts` with `import 'services/fsm/entityMatchmaking'` run via `pnpm exec tsx --tsconfig ./tsconfig.json`.
3. **Prophet client error mapping**: a NATS timeout/connection error becomes `IpseityError.Unknown` / `TreasuryError.Unknown`, NOT `RequestFailed` (pinned by `clients/treasury/request.test.ts`). Don't branch transport-vs-application on `RequestFailed`. Also `MethodNotFoundError` category `not_found` → `IpseityError.NotFound`.

Review-loop meta: 15 rounds × 3 lenses (eng/domain/ops) found real bugs through round 7 and again at round 14 (review-plan precedence); rounds 8–13 were cosmetics with the domain lens still productive. Kevin capped at 15 and reviewed the PR himself. Reviewers flip-flopped on `instanceof` vs `_tag` and on log levels — decide once, write the reason in the PR, don't re-litigate.

See [[matchmaking-owner-gate-design]], [[matchmaking-pii-scoring-architecture]], [[spawned-nova-worktree-is-bare]].
