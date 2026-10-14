---
name: svb-fx-returns-to-concentration-unbooked
description: SVB FX wire returns landing in Concentration ***4469 (not Disbursements ***4473) were never booked in treasury; OW 135871 $24,998.98 + likely OW 135949 $11,476.50, both 9/23/2026. Kevin 2026-10-09: tabled the OW 135949 one only; 135871 handled with the GHB re-send.
metadata:
  type: project
---

Found 2026-10-09 via SVB portal (go.firstcitizens.com, Kevin logs in; search "BUYBACK").
- OW 135871 (CA 439790, Explorer34 Scout Fund IV IVA): sent 9/17 from 4473, FX 253294680000001 €21,760 $24,998.98. Returned 9/23 to **4469**, FX 253481512000001 CASE ID 2171947, $24,998.98. Treasury still shows Completed, no Svb::ReturnedOutgoingWire, no return LE.
- 9/23 4469 also has $11,476.50 return FX 253485631 (€10,000), likely OW 135949 (see [[ca439789-balance-gap]]).
- Returns landing in 4473 were booked normally (136462, 135994 on 10/9). Hypothesis (unverified): returned-wire sync misses 4469.

**Why:** fund ledger short vs real SVB cash; money stranded at SVB. **How to apply:** Kevin tabled it 10/9 during the GHB FX reroute ([[treasury-ghb-fx-reroute]]); raise again when next on CA 439789/439790.

**Update 2026-10-09 (portal-verified, screenshots sent to Kevin):** tie key is the SVB "FX Deal #" on the debit detail == "Return of FX <deal#>" on the credit.
- 135871: debit deal 2026091700586 ↔ 9/23 return case 2171947. CONFIRMED.
- 135949: debit 9/21 $11,476.50 deal 2026092100577 ↔ 9/23 return case 2174433 to 4469. CONFIRMED returned; treasury shows Completed @ $11,468.50, so the $8 SVB-excess leg of #9097 run 10/9 treated a returned wire as completed.
- Unassigned Svb::ReturnedOutgoingWire 1510 ($11,382.10, deal …091700585) and 1512 ($11,378.10, deal 2026091800175) look like this fund's 9/17 and 9/18 €10K Duality wires — OW ids not matched yet.
- Every Duality Robots wire (bank OLINDA SAS, BIC QNTODEB2XXX = Qonto) came back "Regulatory Reason" → likely beneficiary-side, rerouting via GHB may not help.
- The SVB list description sometimes carries "WIREID:<OW id>" (e.g. 135994) — searchable.
- 2026-10-09 later: COMPUTIS (OW 136462) bank = OLINDA SAS Italy BIC QNTOITM2XXX; Vetaion (135994) = Olinda Germany branch → all of Grace's 3 re-sends are Qonto beneficiaries. Recommended holding re-sends until portco gets Qonto's reason (via CR) / SVB gives full return text by case ID.
- 135949's treasury amount $11,468.50 equals a 9/22 SVB debit to LIVIA SPV 1 SRL (deal 2026092200111), not Duality — likely origin of the bogus "$8 excess".
- SVB portal deep links are NOT per-transaction (9/22 and 9/28 details produced the same URL hash); cite FX deal # instead.
- Unverified: 1510/1512 deal #s (…091700585, 2026091800175) vs the 9/17 $11,488.50 and 9/18 $11,480.50 Duality debits.

**Update 2026-10-13:** Qonto blamed SVB's sender BIC; Grace chose an offline send from GHB. Thomas approved covering it from reserves. Kevin ran a manual ARP: one `AngellistReservePayment` (token `GHB-FX-RESERVE-ADVANCE-CA439790-20261013`, $39,530, COVER_FOR_INVESTMENT_WIRE_OUT, expect_repayment) with a hand-built transfer GHB reserve CA 431242 → CCA GHB sub 495715 (TP acct_11mtyptr908363f, open). Completed 10/13. The standard `CreateService` can't do this: it draws from the reserve at the CA's *active* bank (FTB). Pending: Grace queues and holds the wires, then repoint OW `sub_account_id` → 495715, then unhold; `repay!` the ARP after they settle (it returns funds to 431242 via `funding_account_for`). The 135871/135949 return booking is still outstanding.

**2026-10-13 trap (my miss):** ARP 1's reserve transfer 293992 used category TRANSFER into the non-active GHB sub, so on completion `forward_funds_to_active_sub_account_if_needed!` (`transfers/v2/state_service.rb:352`) auto-created NT 293993 (GHB 495715 → FTB, FUNDS_MIGRATION). Only FUNDS_MIGRATION/mirror transfers are exempt. Treasury can't cancel an NT at TP (`base_state_service.rb:33`), so it was left to complete. Re-funded via ARP 2 (token `GHB-FX-RESERVE-ADVANCE-2-CA439790-20261013`), a cross-CA FUNDS_MIGRATION book transfer 431242 → 495715. Kevin repays both ARPs from FTB after the wires settle. **Rule:** any transfer that deliberately lands cash on a non-active sub must be FUNDS_MIGRATION.

**2026-10-14:** ARP 2's money (FUNDS_MIGRATION into 495715) was swept to FTB anyway. A second sweeper: `BalanceChecks::ResolutionService` auto-heal (Flipper `balance_check_auto_heal_inactive_subaccounts`). It runs in `ledger-balance-check` at :05 every 8h UTC (00/08/16), and sweeps any positive TP balance on inactive, non-terminated SAs, whatever category brought it in. GHB Main isn't excluded. **Rule:** cash parked on an inactive sub must leave before the next :05 run, so fund it just before the wires are approved. Wires 138007 (€24 Vetaion), 138009 (€10K COMPUTIS) and 138013 (€21,760 Duality) sit on 495715 in holding_as_created. Plan: Grace provisions all three to ready_for_approval, Kevin funds ARP 3, then Grace approves; the TP submit dispatcher runs every 5 minutes and book-transfers 495715 → GA 14 (intl settlement GHB Main).

**2026-10-14 ~18:40 UTC:** ARP 3 (LE 5935047) funded 495715. Wires 138007 ($27.53), 138009 ($11,473.00) and 138013 ($24,965.24) are all in treasury_prime_offline_processing; forward LEs 5935055/56/57 go 495715 → GA 14 (tp ghb 166754). Residual $3,064.23 on 495715 will be auto-swept to FTB. Open items: repay ARPs 1-3 ($118,590) from FTB. Expected per-sub attribution gap of $36,465.77: provision LEs went IVA@FTB 518425 → OW@495715 with no FTB→GHB cash leg, so FTB ledger ends up below TP and 495715 above. Proposed fix: a ledger-only FUNDS_MIGRATION LE 495715 → 518425 after repayment; confirm against the next 518425 balance check first. Admin UI pages (/v/outgoing_wires/<id>, /v/sub_accounts/<id>, /v/global_accounts/14) work via Chrome when the al read console is forbidden.

**2026-10-14 18:48 UTC:** Kevin moved provision LEs 5935042/44/46 to from_sub 495715 (sub-account attribution fix). ARPs repaid: 11264 (ARP 1) was already repaid via T 294036 (completed); 11266 → T 295649 and 11272 → T 295650 (NT 518425 → reserve GHB sub 164735, created). Remaining: the $3,064.23 residual on 495715 (auto-heal runs only when 518425's balance check fails, otherwise needs a manual FUNDS_MIGRATION), 518425's next balance check, and the still-unbooked 135871/135949 SVB returns.
