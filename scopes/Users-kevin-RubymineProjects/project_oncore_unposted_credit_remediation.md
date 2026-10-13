---
name: project_oncore_unposted_credit_remediation
description: "On-core unposted-preauth-credit bug — fix merged (treasury #8981); BonBillo repaired; Operators Studio CA 351233 phase 2 still OUTSTANDING as of 2026-09-25"
metadata:
  node_type: memory
  type: project
  originSessionId: 5b1765d3-5f92-4ba1-837c-3b815ee329de
  modified: 2026-09-25T18:27:33.061Z
---

**Root cause.** Treasury Prime delivers an on-core preauthorized credit twice — unposted
(`balance: nil`) then posted, under *different* `txc_` ids, so id-dedup can't link them.
`sync_on_core_ledger!` stopped filtering on `balance` in #8638 (2026-08-21), so the unposted copy
was booked as an external deposit and the on-core→capital-collection-account rule in
`IncomingWires::StateService.transfer!` ACHed the money back out. 3 incidents (IW 319668, 320223,
323260), all after #8638; zero in the prior 16 weeks across 758 on-core preauth IncomingWires. The
GHB omnibus path kept its `balance.present?` filter and never broke.

**Fix:** treasury PR #8981, merged 2026-09-24 (`f8be7212f`) — restores the one-line filter.
Verified working in prod 2026-09-25: credit arrived, unposted copy filtered, no phantom, no sweep.

**Repair shape (non-obvious — got this wrong twice before dry-running).** Balances use the
REVISED ledger view (`cash_balance!` defaults `use_audit_ledger: false`), where the phantom's
deposit leg was already redirected to the CCA. So `undo_ledger_entry!` refuses (entry already has a
revision) and `reverse!` double-debits on-core. Correct repair is three entries:
`on-core → CCA`, `CCA → IncomingWire`, `IncomingWire → GlobalAccount 25`.

- **BonBillo CA 337837 — DONE** (Kevin ran it 2026-09-25). `full_internal 51.93` = bank.
  Entries 5882929/30/31.
- **Operators Studio CA 351233 — PHASE 2 OUTSTANDING.** Phase 1 done: Transfer **265887**
  (`sent_pending_arrival`) back-fills the manual ACH `ach_11nbaqzhbes5qbq` so the posted copy
  reconciles instead of hitting the orphan `raise` that wedges that account's sync. Waiting on TP
  to publish the posted copy → sync completes 265887 → then run phase 2.
  Scripts were at `/tmp/repair_operators_studio.rb` on the write console (**gone if the pod
  recycled — re-push from `/tmp/ow136094/` locally, or regenerate**).
  Failing balance checks until phase 2 runs: sa **425846** (8-hourly since 9/23 16:09Z) and
  sa **439420** (since 9/25).

**Traps.** TP *reuses* the unposted `txc_` id (`txc_15wg5n51g2hde852` appeared for both the 9/22 and
9/25 credits) — so never add an unposted `txc_` to `TXN_IDS_TO_SKIP`, it would suppress unrelated
future credits. Also `Transfer` validates origin funds: the origin is the CCA (343279), not the IVA
(343280), which holds nothing.

**Open question, unresolved:** #8638's comment claims TP Support confirmed core accounts report nil
balance *even for settled* credits. Four places in the codebase say the opposite (incl. #8591,
landed 88 minutes before #8638 by the same author). #8638's cited evidence was a misread of internal
Transfer 235595. The merged fix depends on nil meaning "not posted" — worth confirming with TP.

Related: [[feedback_no_long_polling_al_console]].
