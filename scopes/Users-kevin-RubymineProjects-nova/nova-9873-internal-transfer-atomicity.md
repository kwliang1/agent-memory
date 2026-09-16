---
name: nova-9873-internal-transfer-atomicity
description: "nova #9873 discard-on-refusal — verified treasury internal-transfer create IS atomic, so the INTERNAL carve-out is pure conservatism"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6099e449-75aa-4484-a4d7-1946a04626f5
  modified: 2026-09-05T07:08:30.465Z
---

nova PR #9873 (discard a transfer Treasury refused, keep on ambiguous failure) excludes INTERNAL transfers claiming the treasury path is "not verified atomic". Verified 2026-09-05: it IS atomic, at pinned sha bbde842 and current main.

Evidence chain:
- 404/403 raised pre-create in `transfers_handler.rb#create` (L26-35); 422 `RecordInvalid` raised inside `request.origin.with_lock` in `Transfers::V2::CreateService.create!` (L10-46) — full rollback.
- Synchronous completion under the lock is DB-only (fires only for same-sub-account book moves, processor "Ledger", `state_service.rb` L255-292); external execution is post-commit via job (main: transactional outbox `BackgroundOutboxActivityDispatcher`).
- Chain paths (mirror / cross-TP) and unknown errors rewrap as `Transfer::CreationError` → 500/409 → nova maps to externalServiceError/idempotencyConflict → not in the refused set → row kept. Misclassification always errs toward keeping.
- Recovery symmetric: `create!` dedupes on idempotency_token inside the lock, and nova sends transferId as the token (`internal.ts` execute).

**Why:** the PR's refused set (invalidAccount/validation/insufficientFunds/authz from `fromTreasuryError`) can therefore safely trigger `deleteUndispatched` for INTERNAL too; keeping the exclusion perpetuates CREATED orphans for refused internal transfers.

**How to apply:** if a follow-up extends #9873 to INTERNAL, cite this chain; note internal NSF is usually QUEUED (200) not refused, so internal refusals are rarer. nova `transfer.state` is a getter derived from the four terminal timestamp columns, so `deleteUndispatched`'s timestamp+`treasuryTransferId: null` guard is the correct primitive. Related: [[nova-9777-insufficient-funds-block]], [[nova-transfer-balance-reservation-traps]].
