---
name: matchmaking-stuck-scoring-repair
description: Verify + repair an EntityMatchmakingUpload stuck at SCORING; and why a commit run is NOT a safe repair
metadata: 
  node_type: memory
  type: reference
  originSessionId: ed697f4a-ea94-4036-bf7b-95d1ef8cf91e
  modified: 2026-09-17T20:22:21.258Z
---

`entity_matchmaking_upload.status` can read `SCORING` while every row is terminal.
Systematic cause fixed by nova #10099 (merged in #9864): `scoreMatchmakingBatch` now ends
with a `refreshMatchmakingRollup` activity. Residual causes are rare — the refresh burning
its 10 retries, or a run dying mid-scoring (which *should* read SCORING).

In-product reads are unaffected: `getBatch`/`summaryStatus` recompute the rollup and GraphQL
exposes only that. Only Metabase and the Flowdash marts read the stored column.

## Verify (read-only) — paste into `just console -p`

```js
let data = await import('data')
let { rollupStatus } = await import('services/entityMatchmaking/rollup')
let stuck = await prisma.entityMatchmakingUpload.findMany({ where: { status: 'SCORING' }, orderBy: { createdAt: 'asc' } })
for (let upload of stuck) {
  let [, counts] = await data.matchmaking.countRowsByStatus({ uploadId: upload.id }, prisma).tuple
  let computed = rollupStatus(counts ?? [])
  console.log(upload.id, upload.createdAt.toISOString(), `stored=SCORING computed=${computed}`, computed === 'SCORING' ? 'still-scoring' : 'STALE', JSON.stringify(counts ?? []))
}
console.log(`uploads with stored status SCORING: ${stuck.length}`)
```

`STALE` = needs repair. `still-scoring` = has STAGED rows, legitimately unfinished, leave alone.

## Repair — one row, one column, idempotent

```js
let { refreshUploadStatus } = await import('services/entityMatchmaking/getBatch')
await refreshUploadStatus({ uploadId: '<id>' }).tuple
```

Body is `countRowsByStatus` → `setUploadStatus(rollupStatus(counts))`. Touches no row, emits
no FSM event. Used 2026-09-17 on `f168faf0-6bb6-43e3-b3cc-8c81d3499182`.

## Do NOT repair with a commit run

Triggering `adminEntityMatchmakingCommitBatch` also refreshes the rollup (via
`finalizeCommitMatchmakingBatch`), and `commitBatch` has no `rowIds.length` gate — but on a
batch holding `AUTO_MATCH` rows it emits `commit`, and `runPort` in `PENDING`'s `onEnter`
creates a Nova entity + recipient org **per row**. Only safe at zero `AUTO_MATCH`.

Re-staging also repairs, but not from the UI: `StageBatchModal` disables Stage for a
same-content batch that has rows (`EntityMigrationTab/helpers.ts`, `isBatchStalled` is
`PENDING && rowCount === 0`), so it needs a direct `adminEntityMatchmakingStage` call — and
only while no `scoreMatchmakingBatch:<uploadId>` execution is open, since
`startWorkflowIdempotently` swallows `WorkflowExecutionAlreadyStartedError` and reports success.

## If alerting is ever wanted

Cheapest useful coverage is a Datadog monitor on the one silent path's log line:
`Matchmaking batch rollup refresh gave up, leaving a stale stored status`.
A row-count monitor must anchor on `entity_matchmaking_row` (neither table has `updated_at`),
and no single row timestamp spans every terminal — `scored_at` for scoring outcomes,
`completed_at` for commit/reject/validation-error. See [[nova-10099-rollup-refresh]].
