---
name: bank1866-legacy-fallback-removal
description: "BANK-1866 PR #8796 removes legacy record_type provenance fallback in BalanceCheck::Classification; gate 3/3 clean; awaiting Kevin merge"
metadata: 
  node_type: memory
  type: project
  originSessionId: d8fce6c1-82c0-400e-8857-989a6582c30e
  modified: 2026-09-04T21:30:03.003Z
---

BANK-1866 (PR #8796, branch kevinliang/bank-1866, commit ad00b0a8a signed): deleted `LEGACY_CONFIRMED_CREDIT_RECORD_TYPES`/`LEGACY_IN_TRANSIT_CREDIT_RECORD_TYPES` and the record_type fallback branch in `bank_confirmed_credit_row?`; fail-closed `nil` kept. Time gate verified: BANK-1750 flag (#8591) deployed 2026-08-21, 14d > 7d window. `InProgressDetail.bank_confirmed` has `default: false` + rows persist via `serialize`, so every post-#8591 row carries the key. Spec helpers now bake the flag (IncomingWire→true, Transfer→false); two new pins assert flagless rows fail closed; `records_resolver_spec.rb` helper also needed the flag. Review gate: 1 round × 3 lenses (proportionate for verified-dead deletion), all explicit no-concerns; only accepted residual = pre-flag historical records flip pendingIncomingExplained pessimistic in admin (issue's designed age-out, no backfill). 171 balance-check examples green in ember worktree Docker; full suite left to CI (worktree OOM gotcha). NOT merged — awaiting Kevin. Related: [[bank1594-incoming-sla]].
