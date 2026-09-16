---
name: money-to-money-is-dollars-not-cents
description: "Integer#to_money means DOLLARS; Money.new(int) means CENTS — mixing them silently breaks guard assertions in prod scripts"
metadata:
  type: reference
---

`5_787_879.to_money` is **$5,787,879.00**. `Money.new(5_787_879)` is **$57,878.79**.

`Integer#to_money` (money gem) treats the receiver as major units; `Money.new` treats it as minor units. Treasury code stores `*_amount_cents` everywhere, so cents figures pulled from a column or a `format` output must go through `Money.new`, never `.to_money`.

**Why:** on 2026-08-31 I wrote a prod repair script guarded by `raise ... if cab != 5_787_879.to_money`, copying the cents value into the dollars constructor. The write was correct — `cab` really was `$57,878.79` — but the guard compared it against $5.7M and rolled the transaction back. The error is invisible in the output because both sides `format` fine; only the comparison is wrong.

**How to apply:** in a guarded write, prefer asserting against a *live* value rather than a hardcoded constant — e.g. compare `customer_account_balance` to `SubAccounts::BalanceService.external_balance(sub_account)` instead of a literal. That removes the units question entirely and asserts the real invariant. If a literal is unavoidable, write it in dollars (`57_878.79.to_money`) so it reads the same as the `format` output you're comparing to.
