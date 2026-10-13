---
name: project-todo-transfers-table-svb-processor-flip
description: "TODO (2026-09-30) — treasury TransfersTable shows each processor under the wrong bank for every transfer pulled from SVB; data is correct, display is flipped"
metadata:
  node_type: memory
  type: project
  originSessionId: b5e49ee1-6ed2-4ee7-8096-aa2221085908
  modified: 2026-09-30T22:21:47.813Z
---

Kevin asked for this as a local TODO on 2026-09-30 while reviewing the Terran Robotics auto-forward (T200395). Its own treasury PR, separate from #9021.

**Bug:** `frontend/components/TransfersTable.tsx:142-168` always puts the origin's bank (`fromSubAccount.partnerBankProgram`) next to `initiatingPaymentProcessor` and its transfer id, and the destination's bank (`toSubAccount`) next to `receivingPaymentProcessor`. For a transfer whose origin is SVB, those pairings are backwards. T200395 (SVB 137686 → GHB 349505) renders as origin "Treasury Prime | Silicon Valley Bank" with `ach_11n5mbmxak9b5s0`, and destination "Svb | Ghb Omnibus".

**The data is right.** Treasury can't push an ACH out of SVB, so `determine_direction!` (`app/services/transfers/v2/create_service.rb:173`) makes it a debit that the destination side pulls. `Transfers::Metadata#initiating_sub_account` / `#receiving_sub_account` (`app/models/transfers/metadata.rb:164-171`) then swap: when `from_sub_account.svb?`, the initiating side is `to_sub_account`. T200395's metadata is `dir=debit init=treasury_prime recv=svb`.

**Fix:** show each side's processor and transfer id next to that side's own sub-account. When `fromSubAccount` is SVB, the origin gets the receiving processor and id, and the destination gets the initiating ones. Mirror `initiating_sub_account` rather than re-deriving the rule in the frontend, e.g. expose which side initiated from GraphQL.

**How to apply:** don't start until Kevin picks it up. Affects every SVB-origin V2 transfer, so check a few in the UI before and after.
