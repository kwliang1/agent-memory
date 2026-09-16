---
name: nova-transfer-kyc-event-vs-poll
description: nova distribution transfers — event-driven KYC gate is live but the old polling cron is NOT yet ripped out (BANK-1211 Todo)
metadata: 
  node_type: memory
  type: project
  originSessionId: 1e4f5dcc-7268-4add-a6fb-d5591bed1953
  modified: 2026-07-24T06:05:00.481Z
---

nova never initiates a distribution transfer before the recipient entity's Treasury customer account is KYC-verified (VBA/on-platform only; wire/ACH skip the gate). As of 2026-07-24 there are TWO coexisting paths:

- **Event (live, NOVA-871 / PR #7503):** treasury emits `CustomerAccounts::TransfersEligibleEvent` when `verified? && sub_accounts.active.any?` (`treasury/app/models/concerns/customer_account/verification.rb:83`, `sub_account.rb:271`). nova consumes it at `graph/src/clients/treasury/consumer.ts:90` → `handleTransfersEligible` → `initiateForEntity()`.
- **Polling cron (STILL live):** `graph/src/cron/jobs/initiateDistributionPayments.ts` runs `every.minute` (registered `cron/jobs/index.ts:13`), `filterEligiblePayments()` live-checks `detail.verified` via `batchGetCustomerAccountDetails` and defers unverified. This is the "dumb polling" Kevin wants gone.

Removal tracked in **BANK-1211 "Rip out paymentInitiation cron"** (= NOVA-872, parent NOVA-871) — **Todo/unstarted**, assigned Sam Felder. So "we don't poll anymore" is intent, not present reality.

Nuances: cron gate checks ONLY `detail.verified`, not sub-account readiness → Temporal workflow retries "no active sub account" after initiation. Event path is stricter (needs verified AND active sub-account). The every-minute cron is the likely source of alert-spam on test/unverified accounts.
