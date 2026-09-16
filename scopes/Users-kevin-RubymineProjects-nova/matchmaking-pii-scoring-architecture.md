---
name: matchmaking-pii-scoring-architecture
description: "How LP-wallet matchmaking keeps PII off durable surfaces: DocumentService ingest, reference-passing scoring workflow, dedup by documentId, and the open FAILED-status gap."
metadata: 
  node_type: memory
  type: project
  originSessionId: 54e023ad-2887-464c-895e-ba8313742df8
  modified: 2026-09-02T22:19:53.307Z
---

Entity matchmaking (LP Wallet Matchmaking, parent BANK-1872) ports reviewed LP entities. Pipeline: **stage → score → port(commit) → review**. Code in `graph/src/services/entityMatchmaking/`, workflow in `graph/src/lib/temporal/workflows/scoreMatchmakingBatch/`, data in `graph/src/data/matchmaking/`, prisma model `packages/prisma/models/matchmaking.prisma`.

**Hard invariant: no row PII (TIN / legal name / owner email) on any durable surface** — not Temporal workflow input/history, not the FSM `fsm_event`/`fsm_execution` tables, not a nova row. `EntityMatchmakingRow` persists ids + derived signals + a *scrubbed* `error` (static reason strings from `classify.ts`, never cell content). This is why scoring/commit can't just carry parsed rows.

**Ingest + scoring (BANK-1919, PR #9774, reference-passing — supersedes the raw-rows design BANK-1892/1895, de-couples the codec BANK-1884 on this path):**
- The CSV lives in **DocumentService** (uploaded by the client via `reserveIngestFile` presigned URL — BANK-1918; kept over the S3 `File` rail for the PII/no-logging posture). nova reads it back with `documentServiceClient.getLatestDocument(id, user, {fetchFileData:true})` → buffer (no server-side range API — whole-file fetch, slice locally).
- `stage(documentId)` is thin: dedups the batch on **`(org, ingest_document_id)`** (dropped `upload.content_hash`; `ingest_document_id` now required+unique), kicks the durable `scoreMatchmakingBatch({uploadId, documentId, actor})` workflow, returns immediately (client polls). No rows cross GraphQL.
- Workflow: a **prepare** activity fetches (retries while DocumentService finalizes — `isProcessing`), parses via nova's own column contract (`parseIngestRows.ts`: `tin,legal_name,entity_type,owner_email`, xlsx **raw mode** so TINs stay text), creates rows **positionally** (rowNumber = data-row index+1), begins FSM executions, returns PII-free `scoreableRowNumbers`. Then chunks of 25 (`scoreMatchmakingChunk`) re-fetch+parse+slice and join rowNumber→rowId locally to score. Parse failure = non-retryable `ApplicationFailure`; durable-history strings scrubbed to counts/static.

**Known gaps / follow-ups:** batch dedup rides reserve's *client-supplied* hash → nova-owned post-parse dedup is **BANK-1925**. **BANK-1924 (PR #9864, 2026-09-02)** re-scoped: `stage` was ALREADY async (the Linear text saying "synchronous" was stale — don't trust it); what was missing was a server-side byte cap in `fetchIngestCsv` (was client-only) and heartbeats on prepare (`ingestActivities`: startToClose 1h, heartbeat 5m). `FAILED` upload status now exists (stamped only by `failIngest` on a deterministic parse/over-cap failure; rollup never computes it) — but retry-exhaustion still rests `PENDING`/0 rows ("stalled", re-stage repairs). Still open: scoring is a **serial reduce over 25-row chunks that each re-fetch+re-parse the whole doc** (the real large-file cost, unfiled); DS client's `fetch(presignedUrl)` never checks status, so an S3 403 body parses as unreadable → terminal FAILED blocks re-stage (noted on BANK-1932). Commit/port (BANK-1890, PR #9696) also needs owner_email off a durable surface — its async path should ride this same reference-passing rail.

See [[nova-bulk-upload-house-pattern]] for the general parse pattern this adopts.
