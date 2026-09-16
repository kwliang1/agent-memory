---
name: venture-33053-op-routing-half
description: "The date-independent half of venture #33053 is treasury's: OP routing hardcodes the category and ignores the caller"
metadata:
  type: reference
---

venture #33053 has **two** defects. The second is treasury's, and unlike the venture half it is date-independent: the OutgoingPayment rail ignores the caller's category — `ach_pushes_handler.rb:54` hardcodes Disbursement and `outgoing_wires_handler.rb:236-251` falls back to it.

The write-up lives in the venture scope: `venture-33053-wire-category-bug.md`.
