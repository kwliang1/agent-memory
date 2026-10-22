---
name: interchange-schedule-a-fees
description: Where Interchange's "Schedule A" fee schedule lives (platform agreement docx in #nova-interchange) and the per-rail wire/ACH fees it sets, with AL's 10/6 redlines. Fees invoice AL, never the customer.
metadata:
  type: reference
---

"Schedule A" = SCHEDULE OF FEES in the Interchange Advisers LLC Direct Account Platform Agreement (AL Advisors Management is the Intermediary). Latest copy as of 2026-10-15: Aryeh Friedman's 10/6 redline docx in #nova-interchange, Slack file F0C77TA29SQ, https://angellist.slack.com/archives/C0C32DWL44U/p1791295491506699?thread_ts=1790959622.193159&cid=C0C32DWL44U. Unsigned; Aryeh committed to signing by mid-Nov 2026. Not in GDrive or arti.

George (Interchange) 2026-10-14 in #interchange-angellist: no Interchange fees debit customer accounts; Schedule A charges are invoiced to AngelList.

Per-rail (Interchange draft -> AL redline): ACH regular waived (struck in their own draft); ACH reversal $30; same-day ACH greater of $0.50 or 0.50% capped $5 -> cap $1; domestic wire $25 -> $15; FedNow/RTP greater of $0.75 or 0.75% capped $25 -> cap $1; batch transfers waived. Implementation, platform, AUC and per-account fees waived in their draft. Deposit $50k -> $25k. Initial term 1y -> 2y.

Extraction trap: the docx mixes strikethrough formatting (Interchange's own waivers) with tracked changes (AL edits); a plain text dump concatenates them ("$2515.00"). Parse w:del/w:ins and w:strike separately.

Related: [[mmf-interchange-integration]], [[bank-1678-interchange-sandbox-probe]].
