---
name: mmf-frec-deposit-account-routing-collision
description: "Frec deposit accounts are matched/deduped by routing last-4 only, so MMF sell proceeds wire to a stale or foreign sub-account and the IncomingWireSyncService intercept misses silently."
metadata:
  type: project
---

**Root cause of IW 319852 / transfer 238077 (Sell 162, CA 421655), found 2026-09-01.**

`MoneyMarketFund::Adapters::Frec#resolve_active_deposit_account_id!` (`frec.rb:220-243`) picks the Frec deposit account by `maskedRoutingNumber.last(4)` **only** — never the account number. `Applications::MoneyMarketFunds::ProvisioningService#register_deposit_accounts!` (`provisioning_service.rb:31-32`) dedupes the same way ("FREC's only echoed key", `create_deposit_account` is not idempotent). Consequences:

- Only **one** Frec deposit account can ever exist per routing prefix. All TP partner_bank_program 2 sub-accounts share routing `<routing-1 redacted>`; program 6 shares `026015053`.
- When a CCA's `active_sub_account` rotates (old sub closed), the Frec registration is never refreshed. Treasury asks for sub X, Frec wires to whatever ...same-last-4 account is registered.
- Sells 126/148 completed to sub 412794 (routing ...5053). 412794 closed 2026-07-30 → `active_sub_account` flipped to 271136 (routing ...5024) → next sell (162) misrouted to sub 474714, a **different entity's** CCA (CA 420813).

**Why nothing alerted.** `TreasuryPrime::SubAccounts::IncomingWireSyncService.save_new_incoming_wire!` scopes both the MMF intercept (`:38-54`) and the generic V2 matcher (`:160-166`) with `.to_sub_account(sub_account)` derived from the wire's TP account. Every `ErrorTracker` call in the MMF block sits *after* the match (`:62`, `:66`, `:75`), so a sub-account miss is completely silent — the wire just falls through to `IncomingWires::CreateService` and credits the wrong CA.

**Companion bug:** `IncomingWires::AutoAssignService.layer2_extract_evolve` (`auto_assign_service.rb:154-160`) matches any `8-4-4-4-11` hex + whitespace + hex. A bare Frec/Apex settlement reference as `wire_info` (e.g. `"4ac15c2f-b47e-4445-8d50-94846da6ddf d"`) is a false positive → wire stamped `assignment_type=layer2_settlement`. Unlike `layer2_extract_bitgo`, it has no originator gate.

**Diagnostic fingerprint:** `MoneyMarketFund::Sell` in `order_completed` whose transfer is still `processing`, plus a cent-exact `IncomingWire` on some other sub-account. Compare `Transfers::Metadata#to_sub_account_id` against `IncomingWire#sub_account_id`.

**CONFIRMED 2026-09-01** via `Frec::Client.get_deposit_accounts(account_id: '4ec10b54-7e5b-4f66-9ffe-b9f681b98a3b')`. That MMF app has exactly two ACTIVE deposit accounts:
- `...3029` / routing `...5053` — sub 412794 (CA 69332), **closed 2026-07-30**
- `...7300` / routing `...5024` — sub 474714 = **CA 420813, a different entity**

The correct account for sub 271136 (`...6168`) was **never registered**. When 412794 closed and CA 69332's active sub became 271136 (routing ...5024), the resolver matched the only ...5024 entry — the foreign one — and Frec wired $18,750 to CA 420813.

**Blast radius (surveyed 2026-09-01, all Frec MMF accounts): 10 ambiguous routing groups, 5 resolving WRONG right now** — MMF CAs 280821 (Avlok), 425002 (J-Ventures III), 425033 (J-Ventures II B), 425894 (Essence VC IV), 436930 (Texas Fund II). Any sell on those misroutes today. Survey script pattern: for each `AccountProvider::MoneyMarketFund`, group ACTIVE deposit accounts by `maskedRoutingNumber.last(4)`, flag groups of 2+, and compare `find`-first against `operating_account_from_mmf_account(...).active_sub_account.account_number.last(4)`.

Requires the **write** console — the read console has no Frec base URL (`URI::BadURIError`).

See [[treasury-mmf-sell-completion-validation]], [[treasury-prod-console-access]], [[mmf-sell-fee-skip-regression]].
