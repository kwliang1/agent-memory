---
name: project-venture-33053-category-bug
description: Wire/OP withdrawals booked DISBURSEMENT — findings live in BANK-2063 + Arti v4; repair not yet authorized
metadata:
  node_type: memory
  type: project
  originSessionId: d91cb0d8-95ac-4655-9746-0a1a0303eea3
  modified: 2026-10-01T18:32:02.950Z
---

Venture #33053 (2026-08-14..28 window) and treasury's OP routing booked withdrawal LedgerEntries as `DISBURSEMENT`. Investigation finished 2026-09-05 (zinc), persisted 2026-10-01 (glyph) into Linear BANK-2063's description: find-queries with counts (140 OW/277 LE, 1,208 OP/1,201 LE), query traps, affected surfaces, open scope questions. Full write-up: https://arti.internal.angellist.com/s/venture-33053-category-bug/4.

Kevin has NOT yet authorized remediation; counts are a 9/5 snapshot — re-measure via the Arti appendix queries before any repair. The EWA-ownership heuristic (`external_wire_accounts.customer_account_id == origin CA`) was tested and rejected: 112/112 matched, zero discriminating power — don't re-derive it.

The old handoff pointer `~/.claude-byte/.../venture-33053-wire-category-bug.md` is dead; `.claude-byte` doesn't exist. Related: [[feedback-backfill-with-ledger-changes]].
