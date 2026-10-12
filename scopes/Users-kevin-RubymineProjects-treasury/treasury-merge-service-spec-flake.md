---
name: treasury-merge-service-spec-flake
description: "merge_service_spec.rb:42/:147 flake ROOT-CAUSED (BANK-2193) — balance_service_spec before(:all) leaked $1,000 external_incoming_funds rows; fix on kevinliang/bank-2193"
metadata:
  node_type: memory
  type: project
  originSessionId: af9809e6-02e5-48cb-ae57-6b10eb9b710e
  modified: 2026-09-30T22:42:13.749Z
---

`spec/services/customer_accounts/merge_service_spec.rb:42` and `:147` failed intermittently in CI:
`origin_balance` of the oldest ledger entry was -200000 instead of -100000 (PR #9021, #9026 build 34643).

**Root cause (verified 2026-09-30):** `spec/services/accounts/balance_service_spec.rb` group
`insertion performance regression test` had a `before(:all)` creating 5 `:with_balance` customer
accounts + 5 `:with_balance` global accounts ($100 each = $1,000 of `external_incoming_funds` debits).
`before(:all)` runs outside DatabaseCleaner's per-example transaction and nothing rolled it back, so
every later file in the same Knapsack batch saw the rows. It ran even though all 3 examples are `xit`.
Deterministic repro: `rspec --order defined spec/services/accounts/balance_service_spec.rb:449 spec/services/customer_accounts/merge_service_spec.rb:42:147`.

**Fix:** `before(:all)` → `before` on branch `kevinliang/bank-2193`. PR #9027 opened 2026-09-30 (Kevin said push after round 1 of the gate came back clean).

**How to apply:** if this flake recurs after that merges, it's a different leaker. The general lesson is that any DB write in `before(:all)` leaks into later files ([[reference_treasury-knapsack-queue-mode]]).
