---
name: achpush-factory-credits-customer-account
description: The AchPush factory writes a GlobalAccount→CustomerAccount credit for the push amount, even via build+save!(validate: false); balance-delta specs must account for it
metadata:
  type: reference
---

Creating an AchPush in specs (including `build(:ach_push, ...).save!(validate: false)`, as in `spec/services/customer_accounts/balance_service_balances_spec.rb` `save_ach_push`) also writes a GlobalAccount → CustomerAccount ledger credit for the push amount, at the travel_to time. A spec that asserts an absolute net change across a range where a push is created will be off by the push amount (BANK-2311, 2026-11-06: expected 500, got 2,500).

**How to apply:** assert against the ledger delta (`customer_account.balance(as_of: to) - balance(as_of: from) + add-back`) rather than a hand-summed absolute, or create the push outside the range. Also: `let!(:sub_account)` at the top of that spec forces the account (and its `:with_balance` funding) to exist at real "now", so put the range in the future (`from = 1.day.from_now`, moves inside `travel_to(2.days.from_now)`), not in the past.
