---
name: svb-fx-returns-to-concentration-unbooked
description: SVB FX wire returns credited to Concentration ***4469 skip returned-wire detection and become IncomingWires; plus the traps hit while repairing them (INC-5849/5853)
metadata:
  type: reference
---
`process_rejected_outgoing_wires!` reads only the SVB disbursement account (`wire_processing_service.rb:309`). An FX wire return credited to Concentration ***4469 is therefore booked by the BAI2 sync as an IncomingWire, ops can assign it to a CCA as new money, and the OW stays `completed` with no ROW (INC-5849: OW 135871/135949 → IW 323733/323732). RCA: https://arti.internal.angellist.com/s/inc-5849-ow135949-return-rca/1.

**Rules**
- Tie an SVB return to its debit by the FX deal number ("Return of FX <deal#>" on the credit). SVB portal deep links are not per transaction, so cite the deal number.
- An FX return can exceed the original debit (buyback gain). Never infer an "excess" leg from a portal read; check the FBO sum check reconciled before you book (INC-5853 was an $8 leg booked on a wrong premise).
- Before booking any EOF or external leg, check the global FBO sum (`GlobalLedger`), not only the per-sub `ledger_balance`.
- Check `SubAccount#closed_at` before routing cash to a sub.
- Cash deliberately landed on a non-active sub is swept twice over. `forward_funds_to_active_sub_account_if_needed!` (`transfers/v2/state_service.rb`) forwards any non-FUNDS_MIGRATION transfer, and treasury can't cancel the resulting NT at TP. `BalanceChecks::ResolutionService` auto-heal (`ledger-balance-check`, :05 every 8h UTC) sweeps any positive TP balance on an inactive sub, whatever the category. Use FUNDS_MIGRATION, and fund it just before the wires are approved.
- `AngellistReservePayment` `CreateService` draws from the reserve at the CA's *active* bank; covering a send from another bank needs a hand-built transfer.
- `al console exec -- env COMMIT=1 …` does not reach the script; edit the COMMIT line instead.
