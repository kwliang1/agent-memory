---
name: treasury-three-balance-functions
description: Treasury has three different "balance" functions per customer account that return different numbers; only full_internal_balance feeds the balance check
metadata:
  type: reference
---

Three functions, three different numbers for the same account. Naming one "the balance" is how I misdiagnosed Upekkha twice on 2026-08-31.

- **`CustomerAccount#balance`** → `cash_balance(include_balance_in_mirror: true)`. The revised ledger. What the CA admin page shows.
- **`SubAccounts::BalanceService.ledger_balance(sub_account)`** → sums RAW `amount_cents` by `from_sub_account_id`/`to_sub_account_id`, only `not_yield`. Sub-account grain, ignores revisions entirely. Used by the GraphQL sub-account field and `LedgerEntries::SubAccountValidationService` — **not** by the balance check.
- **`CustomerAccounts::BalanceService.customer_account_balance`** → wrapped by `SubAccounts::BalanceService.full_internal_balance`, and **this is the one `BalanceChecks::DifferenceService` records as `treasury_amount_cents`.**

`customer_account_balance` is NOT a balance — it's `cash_balance` plus/minus in-flight reconciliation adjustments so the figure is comparable to the bank: adds pending outgoing wires, ACH pushes/pulls, incoming wires on the active sub-account; subtracts pending V2 transfers out, sent-pending-arrival, forwarding credit, SVB-TAG-without-wire-out. A stuck item in any of those buckets skews the check forever while the account's own balance is perfectly correct.

`full_internal_balance` also **sums the whole IVC family** (capital collection + investment vehicle + disbursement + escrow) for accounts with shared sub-accounts, and **excludes on-core**, which owns its own sub-account and takes the `customer_account_balance` branch directly.

**Why:** a balance check can fail while the CA page and the bank agree, because the check compares a fourth quantity. Always name the function before reasoning about a number. Related: [[treasury-stale-returned-wire-balance-check]], [[balance-check-gaps-discussion]].
