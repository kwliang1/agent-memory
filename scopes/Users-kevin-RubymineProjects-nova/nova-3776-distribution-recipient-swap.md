---
name: nova-3776-distribution-recipient-swap
description: How to swap an in-progress distribution recipient (LLC→individual) across nova+treasury; Bryan Menell/Cusseta case; the FK re-point map + STAGED gate
metadata: 
  node_type: memory
  type: project
  originSessionId: 836782bf-92e0-4c74-a02b-22428abe1fcb
  modified: 2026-08-12T19:15:36.493Z
---

Validated 2026-08-12 for Kevin: swap the in-progress CF2018 distribution recipient from **Cusseta Investments, LLC** → **Bryan Menell** (individual). Cusseta is a disregarded checkbook-IRA entity (Bryan's SSN on K-1); fund admin Russ approved. Thread ctx = [[nova-payment-cancel-not-productized]], NOVA-3776 (blade name/type edit preserves "confirmed" status — flagged bad).

**Treasury IDs (prod):** customer account `8036d65df59e45ee8776a28df0b23e64` (id 464437), owner = LLC entity `019fb033bbef7d1598deaab063133e05` (Company, Unverified). Signatory/major-shareholder/control-person = Bryan's PERSON entity `019fb033c49e77ba9ddbd94de78bdf95`, **Verified**, full PII+KYC (Alloy approved 7/29/26).

**Key model facts (verified in code):**
- Treasury has NO entity/bank_account tables. Entity lives in ipseity. "Individual bank account" = new PERSON `CustomerAccount` via `CustomerAccounts::CreateService.create!(entity_id: <ipseity id>)` — derives owner_type from entity, reuses existing KYC (no re-verify, `Entities::StatusService.verified?`), auto-provisions the SubAccount. Idempotent on `(owner_entity_api_id, account_purpose)`. Bryan's person entity owns NO existing CA → no collision (searched prod).
- Nova has NO `treasuryEntityId`/`treasuryBankAccountId` column. Treasury pointers: `EntityFinancialAccount.treasuryAccountId` + `VirtualBankAccount.treasuryCustomerAccountId`(@unique) → treasury CustomerAccount; `Entity.alIpseityEntityId`(@unique) → ipseity entity; EEBR.externalAch/WireAccountId → treasury external accounts.
- **DP reset + repoint is DONE by nova PR #9420** `graph/engbot/resetDistributionPaymentForEntityChange.ts` (branch `yw/engbot-reset-distribution-payment`, OPEN, by Yewon). Kevin does NOT hand-roll the reset. #9420 is read-only by default (`.plan()`/`.canPerform()`), mutates only under `execute:true`.
- **CRITICAL: #9420 REUSES the existing treasury CA — creates nothing.** Two guards force `args.treasuryCustomerAccountId` == the treasury CA the current LLC wallet is pinned to (= `8036d65…`): `individual EFA treasuryAccountId != reused` and `VBA on treasury acct != pinned wallet`. So **do NOT mint a new PERSON treasury CustomerAccount** (the `CustomerAccounts::CreateService` path) — #9420 fails closed on it. My initial "pointers must change / new treasury CA" was WRONG for this path; Kevin's msg-30 "nova FK pointers to treasury stay the same" is RIGHT (treasury CA value preserved; only Nova rows added/re-homed).
- **What to create before #9420 (Nova-side only):** (1) Nova `Entity` type='individual', `alIpseityEntityId=019fb033c49e77…95`, name Bryan — DOESN'T EXIST YET (verified: Nova admin entity search on his ipseity id = No results; LLC's ipseity id → Nova entity `d6dd2ef7-5f38-4e78-b34b-39e56bc1e05d`). (2) BANK `EntityFinancialAccount` on that entity with `treasuryAccountId=8036d65…`, **NO PRIMARY VBA** (#9420 upserts/re-homes the existing wallet VBA onto it; guard `existingPrimaryVbaIds===0`). Do NOT use full `onboardDistributionRecipient.ts` — it over-creates a VBA/treasury acct and trips the guards.
- #9420 args: `distributionPaymentId, paymentTransferId, transferId, treasuryCustomerAccountId=8036d65…, individualEntityId=<new nova entity>, expectedAmount, execute`. Enforces STAGED/INITIATED gate itself (no `treasuryTransferId`/`ledgerEntryId`; control CREATED or absent; single PT; funds never left; not FSM-enabled org).
- Compliance nuance flagged to Kevin: reuse means payout keeps routing through the treasury CA still OWNED by the LLC (Unverified) — fine since disregarded=Bryan, but treasury attribution stays LLC. New-PERSON-CA path would fix that but #9420 can't consume it.

**Kevin's FINAL decision (2026-08-12, supersedes the #9420-reuse path above):** will NOT reuse `8036d65…`; creating a fresh individual treasury CA (cleaner attribution — money-out owned by Bryan not LLC, addresses the compliance nuance). Editing the existing DirectoryEntity + connectedEntity IN PLACE to reflect Bryan's individual entity. Entity already Verified → no re-KYC.
- ⚠️ I flagged: this shape CANNOT run #9420 (fails closed on reuse-CA guards + `currentConnectedEntityId===individualEntityId` "already connected"). So Kevin is hand-rolling the DP reset #9420 would've done: null recipientConfirmedAt/verifiedAt/approvedAt (+actor cols +payout-email ts), delete the never-executed transfer stub, cancel pending transfer control, repoint Payment.recipientVirtualBankAccountId to new CA wallet. Skip the timestamp-null → lands in NOVA-3776 "confirmed against wrong wallet".
- ⚠️ Also flagged: in-place CE edit of LLC Nova entity `d6dd2ef7-5f38-4e78-b34b-39e56bc1e05d` has GLOBAL blast radius (Yewon's "mutates shared directory entity globally"). Verify it's not the recipient on other CF distributions (CF2017?) before editing; couldn't rule out from admin (distributions view is execution-scoped, not entity-searchable). If shared → new individual Nova entity + repoint instead of in-place.

Jack (nova) waiting to tell LP to restart flow.
