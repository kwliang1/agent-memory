---
name: reference-treasury-batch-account-lookup
description: Treasury batchGet wire/ach index endpoint quirks and EEBR dangling-pointer behavior
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5df453aa-3bce-4bea-8c73-a33bc692901b
---

When comparing/looking up Treasury external accounts referenced by `EntityExternalBankReference` (EEBR):

- `clients.treasury.batchGetExternalWireAccounts({ ids })` hits Treasury's `external_wire_accounts` `index` endpoint, which **silently excludes `REJECTED` wire accounts** — they exist in Treasury but the batch call won't return them. Use the by-id `showExternalWireAccount` (requires `entityId` + `entityIdType`) to retrieve a rejected wire.
- `clients.treasury.batchGetExternalAchAccounts({ ids })` silently omits ids that don't resolve — a missing id from the batch result means the ACH account genuinely doesn't exist in Treasury.
- `EntityExternalBankReference.externalWireAccountId` / `externalAchAccountId` are plain `String?` columns with **no FK** to Treasury, so dangling pointers (stale ids that no longer resolve) occur and accumulate. The only DB constraint is `entity_external_bank_reference_account_check` (at least one rail set).
- When both rails are set, their account numbers always match — but this is **emergent/structural, NOT an enforced guard**. No code compares the two numbers and no DB constraint relates them. Every creation path threads a single account number into both rails: `upsert` (`graph/src/services/externalBankReference/upsert/index.ts`) feeds `bankDetails.accountNumber` to both `createExternalAchAccount` (accountNumber) and `buildWireAccountFields` (beneficiaryAccountNumber), and matches existing ACH via `getCounterparty({accountNumber})`; clone/link (`externalWireAccount/clone.ts` + `externalAchAccount/clone.ts`) and DP snapshots copy field-for-field from a source EEBR. So a divergent pair is possible in principle (new path, manual Treasury swap, data fix) and nothing would reject it. June 2026 audit: 199/199 comparable EEBRs matched, 0 mismatch. Residual gap: venture-import path (`upsertFromVentureInvestmentEntity`) takes pre-provisioned account ids — not traced to source.
- `request()` in `graph/src/clients/treasury/request.ts` runs `stripUuid` (dash removal) on ids before sending; responses are camelCased via `snakeToCamelCaseDeep`. Wire account number field is `beneficiaryAccountNumber` / `beneficiaryAccountNumberLastFour`; ACH is `accountNumber` (nullish) / `accountNumberLastFour`.

Empirically (June 2026 audit): among EEBRs with both rails populated where both resolved, wire and ACH account numbers all matched — the only anomalies were rejected-wire and nonexistent-ACH buckets.
