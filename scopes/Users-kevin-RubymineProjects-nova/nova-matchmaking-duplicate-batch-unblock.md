---
name: nova-matchmaking-duplicate-batch-unblock
description: "How to unblock a matchmaking batch blocked as a duplicate upload: stalled predicate, zero delete mutations, the upload-delete cascade map, and the non-destructive re-stage escape hatch (adminEntityMatchmakingStage on the existing documentId)."
metadata: 
  node_type: memory
  type: project
  originSessionId: cda35891-f09f-4f32-bc13-2ae715f4ba49
  modified: 2026-09-11T20:43:57.509Z
---

Investigated 2026-09-11 (Kevin's 80-row Fund 5/6 LP porting batch blocked by `StageBatchModal.tsx:164` `duplicateBlocked`). Verified against `nova@main db3dd3429d`.

**The "stalled" escape hatch is narrow and NOT nudgeable.** `helpers.ts:132` `isBatchStalled = status === PENDING && rowCount === 0` — it models exactly one failure (ingest died before any row landed). `rowCount`/`status` are server-derived rollups (`uploads.ts:18` `toSummaryFields` ← `rollup.ts`), so faking it means deleting every row AND forcing status to PENDING — strictly worse than deleting the batch.

**There is genuinely no delete/archive mutation.** `graph/src/internal/schema/admin/entityMatchmaking/` = 10 mutations / 8 queries, zero removals (commitRow, forceSyncRow, deselectCandidate, stage, bulkRejectRows, bulkCommitRows, reserveIngestFile, commitBatch, bulkForceSyncRows, selectCandidate). A delete means an engbot script (`graph/engbot/`, precedent `deleteOrganization.ts`, REPL-pasted per `packages/engbot/AGENTS.md`) or raw SQL.

**Upload-delete cascade map** (`packages/prisma/models/matchmaking.prisma`): `entity_matchmaking_row` Cascade → `entity_matchmaking_candidate` Cascade AND `entity_matchmaking_commit_idempotency` Cascade (the sharp edge — the commit guard and the whole `forcedBy`/`rejectedBy`/`selectedBy` audit trail go). `entity_matchmaking_ingest_file` **survives**: its FK `onDelete: Restrict` sits on the upload, blocking deletion of the FILE, not the upload. So a delete + re-stage reuses the same DocumentService document — **no second copy of the TINs.** Already-committed rows keep their nova Entity + recipient org + EFA + treasury linkage; a re-port degrades to a wallet-ensure upsert (`executePort.ts:190` dedups on `alIpseityEntityId`), so mostly benign but with the guard deliberately removed. Only clean when zero rows have committed.

**BEST answer is usually neither option — re-staging is already idempotent and non-destructive.** `stage.ts` `findOrCreateUpload` converges on the existing batch by `ingestDocumentId`; `kickIngest` uses a deterministic per-upload workflowId ("so a re-stage (repair, or scoring newly enabled) re-runs idempotently"); `prepareBatch.ts:92` `ensureRows` returns existing rows untouched when `existing.length > 0` and only re-drives un-begun/stuck executions. **The UI guard is the ONLY blocker.** So the cheap unblock is one mutation on the EXISTING document id:
`adminEntityMatchmakingStage(input: { documentId: "<existing>" })` — get the id from `adminEntityMatchmakingIngestFile(uploadId:)`. Zero schema change, zero data loss, zero new PII copy.

**Never hash-shift to force a duplicate through.** `reserveIngestFile.ts:154`: *"Reserving a second document for rows that already have one leaves a permanent, unreferenced copy of the same TINs — DocumentService has no delete endpoint."*

**Adding an empty `owner_user_id` column is a total no-op** (the case that started this). `hashParsedRows` (`csv.ts:24-39`) omits `ownerUserId` when `undefined`, so the hash is unchanged *by design* — but it also carries no new information: `parseOwnerUserId` rejects blank/`0` and the gate ladder falls through to `owner_email` anyway. Verified empirically on the real files: both hashed to the same 4-tuple digest, 80 rows, 0 of 80 `owner_user_id` populated, 71 distinct TINs (9 twice), 0 blank names/emails. The block was correct, not a bug.

See [[nova-entity-migration-names-docservice-sso]] (blank Entity-name column = expired AWS SSO, the co-occurring symptom here), [[nova-matchmaking-owner-gate]], [[nova-lp-porting-review-tab]], [[nova-bank-1943-commit-idempotency]].
