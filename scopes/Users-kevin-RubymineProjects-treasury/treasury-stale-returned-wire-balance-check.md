---
name: treasury-stale-returned-wire-balance-check
description: Treasury balance-check failure mode — an IncomingWire marked returned without its outbound leg holds a ledger balance forever and inflates the check
metadata:
  type: project
---

Recurring balance-check failure (Upekkha, 2026-08-31, CA 311974 / SA 513688, $198,300).

A correctly returned wire has FOUR ledger legs: `Global → IW` (received), `IW → CA` (transferred), `CA → IW` (reversal), **`IW → Global` (returned out)**. When a wire is transitioned to `returned` without the fourth — the known return-automation gap, `return_transfer_id` nil — the reversal puts the money back ON the wire and nothing takes it off.

`CustomerAccounts::BalanceService.customer_account_balance` includes
`customer_account.incoming_wires.where(sub_account: active_sub_account).sum(&:balance)` with **no state filter**, so a returned wire holding a balance is added back on every run. The check fails forever while `CustomerAccount#balance`, `ledger_balance` and the bank all agree. See [[treasury-three-balance-functions]].

Fix = write the missing leg, copying `IncomingWires::StateService#return!`'s provisioned branch:
`origin: iw, destination: GlobalAccount.external_outgoing_funds(partner_bank_program: iw.partner_bank_program), category: RETURN, amount_cents: iw.amount_cents`.

**Do NOT pass `from_sub_account: iw.original_sub_account`** even though `return!` does — for a wire past provisioned that attributes the debit to whatever sub-account the wire first landed on (for Upekkha, the *on-core* sub, which was already correct). The proven shape has `from_sub: nil`; omitting it lets `set_sub_accounts` (`||= origin.try(:active_sub_account)`, nil for an IncomingWire) produce that naturally.

**How to apply:** find them with `IncomingWire.where(state: 'returned').select { |w| w.balance.to_money != Money.zero }` — only 2 existed system-wide on 2026-08-31. Guard the write in a transaction that rolls back unless `customer_account_balance` lands on the bank figure AND neighbouring sub-accounts are unmoved. Related: [[incoming-wire-return-automation-gap]], [[incoming-wire-manual-return-gotchas]].
