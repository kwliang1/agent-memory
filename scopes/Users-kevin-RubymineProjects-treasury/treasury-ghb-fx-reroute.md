---
name: treasury-ghb-fx-reroute
description: Recipe and traps for manually rerouting an FX outgoing wire from Piermont/FTB to the fund's GHB Main sub-account (SVB can't do the currency)
metadata:
  type: project
---

Pattern seen 10/9 (OW 138007/9/13, CA 439790, GHB SA 495715) and 10/20 (INC-5805, OW 138445 CHF, CCA 415688, PSD 508360 → GHB 471351). Script: FUNDS_MIGRATION active SA → GHB SA on the CCA (IVC: the IVA rides on the CCA's subs), token `GHB-FX-REROUTE-OW-<id>`, then `ow.update!(sub_account_id: ghb)`. Mirrors `route_through_svb!` args.

- Repointing to GHB also stops auto `route_through_svb!` at submit (`treasury_prime/outgoing_wires/state_service.rb:41`, only fires for piermont/fifth_third).
- Submit book-transfers wire → settlement GA 14 (GHB 166754) from `ow.sub_account`; the GHB SA must hold the cash at TP first.
- **Point the wire back to the active SA before Confirm and Complete.** Excess refund goes settlement → CA active SA (`transfers/create_service.rb:97`), then on completion wire → CA from `ow.sub_account` (`treasury_prime/transfers/state_service.rb:158`), which is a second NT from the emptied GHB SA. A short book-transfers from the empty GHB SA.
- Inactive-SA sweep: auto-forward skips FUNDS_MIGRATION (`transfers/v2/state_service.rb:357`); balance-check auto-heal runs 00:05/08:05/16:05 UTC and only if the active SA's check fails. Fund just before approval.
- The ledger fix (edit `from_sub_account_id` on provisioning LEs) was needed on 10/9 only because the GHB reserve paid (ARP) and the wire was repointed before provisioning. When the wire is provisioned on the active SA and a real FUNDS_MIGRATION moves the cash, the books match the cash.
- The incident text may name the wrong bank (INC-5805 said FTB; it was Piermont SD). Check prod.
- **Network transfers are not instant on every lane.** Prod, 30d to 2026-10-20 (created→updated): Piermont SD → GHB Main median 15.9h (n=97); FTB → GHB median 1.0h. Measure the lane before quoting a sweep window; I told Kevin "minutes" for PSD→GHB and he corrected it.
