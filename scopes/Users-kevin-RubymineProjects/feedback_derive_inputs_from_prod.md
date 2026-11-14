---
name: feedback_derive_inputs_from_prod
description: "Don't ask Kevin for ids/rows a read-only prod query can derive; run the query yourself."
metadata:
  node_type: memory
  type: feedback
  originSessionId: 2aadff4b-f370-4e2b-b40f-3a5f68b44427
  modified: 2026-11-06T08:11:57.018Z
---

Before asking Kevin for record ids, upload ids or row numbers, run a read-only prod query that derives them yourself.

**Why:** For BANK-2217 (2026-11-06), five sessions in a row asked Kevin for the backfill's upload ids and row numbers. He asked, "Can you not derive it from a prod console read now?" One query on the nova read console returned all 51 dedup-ported rows.

**How to apply:** If an input is in the DB, query for it, using [[nova-prod-db-access-from-bridge]] for nova. If there's no console, `al console c -a nova -e prod --no-attach` creates one (al lives at `/Users/kevin/bin/al`). Ask Kevin only for what isn't stored anywhere.

Also: his replies in the bridge thread can arrive without an inbound notification. When a long-standing question is open, re-read the thread with `slack_read_thread` before re-asking it.
