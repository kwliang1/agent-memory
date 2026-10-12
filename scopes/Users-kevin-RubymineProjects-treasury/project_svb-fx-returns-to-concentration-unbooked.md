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
