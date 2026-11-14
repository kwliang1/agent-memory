---
name: payment-activity-qt-funded-duplicate-rows
description: QT-funded AchPush/OW get two payment_activities rows per account; the customer LE settles the QT row, the payment row stays Completed with no LE forever
metadata:
  type: project
---

The customer-side LE (CA → AchPush/OutgoingWire, booked right after creation) maps via `PaymentActivities::InfoService.payment_of` to the funding **QueuedTransfer**, so it settles the QT's row. The payment's own row on the same account can't take that LE (unique `(ledger_entry_id, customer_account_id)`), so it stays `ledger_entry_id: nil`. `DetailsService#state` reads the payment's state machine, so the row reports Completed. `PaginationService` returns both rows, so the movement appears twice.

Verified 2026-11-03 (prod read console): AchPush 106492 (LE 5336959 on QT 87631's row), OW 73850 (LE 4046896 on QT 15588's row). Completed rows with no LE: OW 3,533, AchPush 2,668, CT 3,138, Transfer 763, IW 597, plus 75.7k QT rows with no LE (cause unverified). Heavy in 2025-26, so this is ongoing, not legacy.

**Why:** I first claimed these LEs went "payment → GlobalAccount" because `ledger_entries_of(payment)` returns only the settlement leg; Kevin corrected me ("it's ledgered to the customer immediately"). Query LEs by requester/origin/destination, not via `ledger_entries_of`, before claiming a payment has no customer LE.

**How to apply:** Context for NIS-4430 / the `treasuryAccountActivity` flag. Yewon's closed #9319 fixes the reverse case (LE with no row) and doesn't touch this.
