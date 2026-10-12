---
name: project_mmf-sell-balance-check-sla
description: "MMF sell in-flight gap no longer alerts in balance check within 3bd SLA — stack #9061 (SLA pin) → #9062 (classification); opened 2026-10-06"
metadata:
  node_type: memory
  type: project
  originSessionId: bbf7529c-4cf1-4cfc-8f63-6c34ccb34078
  modified: 2026-10-06T18:48:31.994Z
---

Stack opened 2026-10-06 (plain GitHub base-chained PRs, not gt): #9061 pins `wire/frec submitted_to_completed` at 2bd/3bd (values unchanged — previously via the TP queued alias). #9062 collects `MoneyMarketFund::Sell.pending` as in-progress rows on MMF sub-accounts, graded by `evaluate_transfer_sla(sell.transfer)`; within-SLA subset match → `expected_to_settle` and excluded from the `check_account_type:mmf` failed gauge; critical → `needs_review`.

**Why:** run f25b9857 had 2 of 3 MMF failures exactly equal to a pending sell's net (CA 421655/Sell 168 $19,955; CA 432337/Sell 169 $12,955). The 3rd (CA 388937 −$20) is the known Frec cash drift [[mmf-frec-uninvested-cash-drift]].

**How to apply:** gap per sell = gross before legs post (`ledger_entry_id` nil), net after. 11-sell latency sample: p50 1.46bd, p90 1.67bd, max 6.27bd (Sell 162). Declined in review: gap-direction guard on `mmf_sell_past_critical?`, excluding MMF rows from bank outgoing-debit predicates (structurally gated by `in_progress_adjustment_applied`), decoupling specs from prod SLA config.
