---
name: upekkha-oncore-reconciliation-state
description: "Handed to flint 2026-08-31 — Upekkha on-core audit/sub-account divergence: what's fixed, what's open, and two repairs proven harmful"
metadata:
  type: project
---

Upekkha Accelerator Fund. `CA#311974` = fund (CCA), `CA#327651` = on-core. Subs `513688` (fund, DIBS/GHB), `403357` (on-core, GHB). Handed to flint 2026-08-31; do not re-derive from scratch.

**Fixed 2026-08-31:** `IW#317808` was `returned` while still holding $198,300 (missing its `IW → external_outgoing_funds` leg), which `pending_incoming_wire_balance` added back on every run — see [[treasury-stale-returned-wire-balance-check]]. Wrote `LE#5835941`; balance check on `513688` went `naturally_resolved`. A follow-up corrected that entry's `from_sub_account_id` 513688 → 403357.

**Still open:**
```
CA#311974  audit -$338,721.21   revised  $57,878.79   (bank-correct = revised)
CA#327651  audit +$594,900.00   revised       $0.00
SA#513688  ledger $57,878.79    bank $57,878.79   OK
SA#403357  ledger $396,096.65   bank      $0.00
OW#133677  rejected, audit $0.00, revised +$198,300
```

**Root cause:** four entries corrected by setting `revised_amount = 0` **directly** instead of via `RevisionService`, so no revising entry exists to offset in audit. Only `5801917` got its pair (`5803144`, `5816165`). Unpaired: `5796129` (`OW#133677 → CA#327651`), `5804886` (DCR#7115), `5816291` (DCR#7132). The zeroing was intentional per Kevin; the missing half was the audit-side offset.

**Two repairs proven harmful — do not attempt:**
1. **Writing three reversing entries.** `set_sub_accounts` runs on every new record including revision entries, and `SubAccounts::BalanceService.ledger_balance` filters nothing — so reversals move sub-account balances at face value. Result: `513688` → $454,478.79 (+$396,600 hole in the one exact account), `403357` → −$503.35. No sub-account assignment satisfies both; `to_sub_account` must belong to `CA#311974`, whose only live sub is `513688`, and `set_sub_accounts` auto-fills it via `||=`. Also: `emit_treasury_event`'s payload has no `revised_ledger_entry_id` field, so three fictitious $198,300 movements would reach Prophet/nova indistinguishable from real cash.
2. **Reversing `5796129`.** `OW#133677`'s audit $0 is already correct for a rejected wire; that entry would assert a movement that never happened, irreversibly.

**Preconditions — all three now answered (2026-08-31):**
- **The $503.35 is diagnosed and unrelated to the $198,300 story.** Two 2024 auto-forwarder entries: `LE#4204906` ($205.03, 2024-04-04, `CA#311976 -> CA#311976`) and `LE#4377528` ($298.32, 2024-07-23, `CA#311974 -> CA#311974`), both "Forwarding funds from incoming wire", both `from_sub 403357 -> to_sub 393357`. They debit on-core's sub-account for migrations belonging to *other* customer accounts — neither `311976` nor `311974` owns `403357`. Same sub-account-attribution bug class as the rest of this incident: `IncomingWires::StateService` passes `from_sub_account: incoming_wire.original_sub_account` (on-core, where wires land) while origin/destination are the wire's own customer account.
- `SA#403357.closed_at` is **nil**, and it is `CA#327651`'s active sub-account — no stale-assignment exposure.
- Both CAs share `owner_entity_api_id = c655b60821bd42c5bcfe347ce7925216`, so `CustomerAccounts::ValidateService.validate_transfer` short-circuits between them.

**Context:** `SA#393357` (fund, GHB Main) closed 2026-08-05 18:44:36 at the same instant `SA#513688` (Increase/GHB) opened — the fund changed banks the day before the IKYAM wire sequence began on 08-06.

**Likely correct fix is code, not data:** the real exposure is `refresh_revised_amount!` recomputing `revised_amount = amount + 0` and silently un-zeroing all three, restoring $594,900 to the customer-facing view. Currently **unreachable** (its only callers key off cross/queued transfers these rows lack). A one-line guard removes it with no ledger writes and no Prophet events.

**Nuance worth keeping:** "audit ending balance == revised ending balance" is an *emergent property of correctly-paired revisions*, not an invariant the codebase enforces. See [[treasury-three-balance-functions]].
