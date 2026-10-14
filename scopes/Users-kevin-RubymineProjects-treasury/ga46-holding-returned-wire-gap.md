---
name: ga46-holding-returned-wire-gap
description: GA 46 (GHB holding) $15k ledger>bank gap = two bank-returned incoming wires covered from holding with no ledger; TP returned-wire sweep recipe; 6 mismatches found 2026-10-05
metadata:
  type: project
---

2026-10-05: GA 46 ledger $137,437.02 vs TP $122,437.02. Two incoming wires were returned at the bank, Treasury never booked the returns, and holding-account cash covered the customers' overdrafts:
- IW 283034 ($10k, CA 417644): manual book `book_11mntk0a81qe721` on 2026-01-06; BT 786235 is mis-attached to LE 5223408. CA 417644 already has BalanceHold #21 ($10k, "reimbursement to AngelList").
- IW 286383 ($5k, CA 395640): duplicate release book `book_11mnrkbz81b44ry` with no BookTransfer row.
Repair script (cover ADJUSTMENT GA46→CA + CA→IW RETURN + IW→GA9 RETURN + Returned state; checked against TP in a txn) passed a rolled-back prod run. **COMMITTED by Kevin 2026-10-05 20:56:19 UTC** (LEs from 5916276); GA 46 = TP. CA 417644 shows available −$10k only because of pre-existing BalanceHold #21.

**Sweep recipe:** TP `incoming_wire?status=returned&page_size=100` (paginate `page_next`), match on `IncomingWire.treasury_prime_wire_id`. 327 at TP; 6 not returned in Treasury: the 2 above, plus 214740 ($230,970 hold) and 247427 ($7,500 hold), which need an IW→GA9 RETURN; 274172, where only the state is stale; and 213992 (2023), untraced.
GA 47 (Piermont Crypto holding) was $892.89 off (ledger > TP), untraced.

Don't use `IncomingWires::StateService.return!` for these: it raises when original_sub_account is nil, and it starts a real Transfer when the customer has migrated subs. Related: [[incoming-wire-return-automation-gap]], [[treasury-stale-returned-wire-balance-check]].

**Hold #21 is the recovery mechanism; do not cancel it.** Thomas Ambrosia placed it (2026-08-14). His write-up is in #fund-product-ops thread 1784750562.992729. The plan is FUNOPS-785, "Undo Q1 investment for Amy Wister": the refund pays back GA 46. After the repair, the payback must be a REAL CA 417644 → GA 46 book (ledger and bank move together), then release the hold. A ledger-only credit to GA 46 would recreate the $10k gap.

Status (2026-10-14, unverified, carried from the index line): root-caused 2026-10-05; repair committed; 4 more stale returned wires and the GA 47 $892.89 lead still open.
