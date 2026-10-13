---
name: ga14-intl-settlement-gap
description: GA 14 (INTERNATIONAL_OUTGOING_WIRE_SETTLEMENT, GHB Main, sub 166754) $944,971.98 ledger-over-bank gap traced 2026-10-09 to 3 completed intl OWs with no/short GA14→GA9 drain leg; nothing repaired yet
metadata:
  type: project
---

2026-10-09: GA 14 ledger $977,540.08 vs TP $32,568.10 → gap $944,971.98. GA 9 = EXTERNAL_OUTGOING_FUNDS GHB Main (the drain target of `transfer_funds_from_international_wire_account!`).

Three completed OWs forwarded into GA 14 but never drained (no GA14→GA9 LE with requester OW, or short):
- OW 91987 (2024-11-08, ROLLEE, FX) — $141,089.00, no drain leg; wire amount edited down, refunds churned.
- OW 108696 (2025-08-15, OMOS, FX, short-adjusted $2,950.05) — $210,550.05, no drain leg. Likely a hand completion (PR #9017 says ~20 since 2023).
- OW 110776 (2025-10-07, MOMENTUM APPS) — operator confirmed amount $0.38 → $600,000 "excess refund" + $0.38 drain; "INC fix human error" revised the refund to 0 but never added the $600,000 drain.
Sum $951,639.05; residual −$6,667.07 not yet decomposed. Other non-zero OW nets are legacy and offset (returns via GA 9 lack requester, so per-OW attribution splits them).

TP `account/acct_11hkntap104mscr/transaction` returns nothing before 2025-09-30 (txc_ era) — can't cross-ref the first two in TP. GA 14 balance-check records exist only 2023-12-29..2024-01 and 2025-05-26 onward; diff never zero. Per-OW net script approach: revised_only.not_yield.not_mirror_transfers, key by OW counterparty or requester.

**UPDATE 2026-10-09 evening:** PR #9115 merged and ran (LE 5927353–55); GA 14 = $25,901.03, BANK-2269 tracks it; research artifact https://claude.ai/artifact/TiasorWE2Jw3DZvYVWGdCd. **The "−$6,667.07 residual" was WRONG** — it was net of five Oct 2026 `submitted_offline` OWs (137142/137209/137004/137375/137744, $130,650.57) that TP shows already sent. Real residual ≈ ledger $128,566.64 BELOW bank once those confirm. Lesson: before quoting a GA14 residual, pull recent TP txns and subtract wires already sent but still submitted_offline. First lead: $90,000 manual intl wire to DAVE.IO on 2026-09-28.
