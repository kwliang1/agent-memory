---
name: tp-nil-transaction-balance-filters
description: "TP core-account transaction-level balance is cached/lagging (nil is normal); the 3 places treasury filters on txn[:balance].present? and why only the on-core one was the bug"
metadata: 
  node_type: memory
  type: reference
  originSessionId: bec248dc-abbd-4f63-b5de-63c75795907d
  modified: 2026-08-21T23:22:08.488Z
---

**TP fact (confirmed by TP Support email 2026-08-21, PR #8638):** for a **core account** (a real DDA bank account created via the TP API — the per-fund `on_core_account`, "replaces our old external SVB accounts"), the *account* balance is accurate **regardless of the transaction-level `balance` field**, which is cached and can lag ("might populate on Monday"). So a `balance: nil` on an otherwise-valid `type:"deposit"`/`type_source:"ach"` preauth credit is EXPECTED on core accounts, NOT a pending/unsettled signal. Real incident: a $15,829.44 preauth credit (`ach_11n8ga6pb02q09c`/`txc_15wp67w2gb07z4g6`) was silently dropped → LP wire completed manually.

**Three `txn[:balance].present?`/`.blank?` drop-filters in `app/services/treasury_prime/sub_accounts/transactions_service.rb` — they are NOT equivalent:**
1. `sync_on_core_ledger!` (~L213) — `.select { balance.present? }`. **This was the bug (fixed in #8638: filter removed).** On-core path, driven by the `sync_on_core_ledgers` cron (`lib/tasks/treasury_prime.rake`, no webhooks). Downstream `AchSyncService.process_on_core_preauthorized_credits!` keys off `amount/desc/ach_id/id`, never `balance`; #8638 also added `next if amount <= Money.zero` there (mirrors the incoming-ach-push guard) since removing the filter widens the input set.
2. `sync_ghb_omnibus_ledger!` (~L177) — `.select { balance.present? && cents >= 100 }`. **Left unchanged (correct as-is).** Omnibus (`acct_11j0pmd219kc8dr`) is the pooled FBO account — a DIFFERENT TP account type, **webhook-driven** (`webhook_service.rb` `account.update`), where nil balance still means pending. TP's core-account guarantee does NOT apply. Higher blast radius (`>=100` microdeposit floor + reconciles many customers' CrossTransfers/Transfers). Don't touch without a TP confirmation specific to the omnibus account.
3. `pending_incoming_credits` (~L138, added by BANK-1750/#8591) — `next if txn[:balance].blank?`. **Latent gap flagged, not yet fixed.** This is the balance-check facade collector (feeds bank-confirmed-inbound classification — see [[op-balance-check-classification]]). It runs over core accounts too, so it can MISS a posted-but-nil-balance core credit → balance check won't flag it as bank-confirmed. Follow-up on that path separately.

**Residual risk called out in #8638 review (not code-fixable — needs TP):** removing filter #1 removes the only "posted" proxy, and the `transfer!` after wire creation is unconditional. TP's `/transaction` payload has no `status`/`posted_at` field to filter on. Safe only if TP's core feed lists posted-only credits under a single stable txn id; ACH returns are handled by existing reversal. Get TP to confirm the core feed lists only posted credits. Related: [[incoming-ach-unledgered-recon]].
