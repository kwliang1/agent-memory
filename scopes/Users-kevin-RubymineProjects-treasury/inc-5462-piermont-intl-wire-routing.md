---
name: inc-5462-piermont-intl-wire-routing
description: "INC-5462 Piermont/PCBB intl wire routing divergence — verified you should NOT collapse beneficiary-bank ABA to the correspondent's; #8515 (show both, labeled) is correct."
metadata: 
  node_type: memory
  type: project
  originSessionId: 48ff2274-fa63-4105-abed-2c9f000f0d38
  modified: 2026-08-12T17:44:09.920Z
---

INC-5462 (2026-08-12, P0): Dillon saw the intl wire routing in the Nova pop-up ≠ the downloaded PDF for Thursday Ventures 1X Holdings 4 LLC (treasury CA `e2554bdd…`, program `piermont_bank_standard_deposits_direct`).

**Mechanism (treasury):** intl instructions ARE generated. Two code paths diverge for the same PCBB-routed account:
- Nova pop-up ← Prophet `WireInfo` (`WireInfoService`, `wire_info_service.rb:231`) carries `intermediary_bank.routing_number = PCBB <routing-2 redacted>`; Nova headlines it.
- PDF + treasury admin card ← `InfoService#build_ghb_international` (`info_service.rb:206`): primary "ABA/Routing" = `sub_account.routing_number` = Piermont's own domestic `<routing-1 redacted>`; PCBB routing was dropped (struct had no field). PR #8515 adds `intermediary_routing_number` + a labeled row.
- Separately, treasury admin `SubAccountCard.tsx:467-487` gates the intl toggle to v1 program names only (omits `*_direct`) — different surface than Dillon's original report.

**DECISIVE source (Piermont Bank's own official "International Wire Transfers" sheet, piermontbank.com/wp-content/uploads/2023/01/Piermont-Bank-International-Wire-Instruction-2023.pdf, Rev 1/23/2023):** the bank publishes BOTH ABAs, labeled — Intermediary = PCBB (SWIFT `PCBBUS66`, ABA `<routing-2 redacted>`); Beneficiary Bank = Piermont (ABA `<routing-1 redacted>`); then Beneficiary Customer name/addr/acct. No collapsing, no FFC language. So do NOT collapse. (MT103 field 56 intermediary vs field 57 account-with-institution corroborates the two-role structure; UNFCU corroborates a no-SWIFT US bank publishing its own ABA — but Piermont's own sheet is the authority.)

**Compared the actual generated PDF (Thursday Ventures 1X Holdings 4 LLC, acct <acct-3 redacted>) to the official sheet:** our PDF's primary "ABA / Routing Number" = `<routing-1 redacted>` is CORRECT (matches Piermont's beneficiary-bank ABA). The ONLY gap = missing "Intermediary Bank ABA `<routing-2 redacted>`" row → exactly what #8515 adds. So the incident RCA framing ("PDF prints the wrong ABA, should be <routing-2 redacted>") is MISCHARACTERIZED — `<routing-1 redacted>` belongs in the primary field; `<routing-2 redacted>` is a second/intermediary number, not a replacement.

**Fix set:** land #8515 (PDF gap) → PDF then matches official sheet field-for-field. Separately fix Nova (`buildAlternativeNonUSRows`) + venture (`wire_manual.rb`) to STOP collapsing the headline routing to PCBB `<routing-2 redacted>` (that's the genuinely-wrong surface Dillon saw). Kevin's original instinct (generated, display/representation issue, not a wrong-number bug) was right. Reinforces [[verify-domain-premise-before-crediting]].
