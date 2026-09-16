---
name: cptr-backdate-trap-venture-half
description: "Backdating a treasury LedgerEntry strands venture CPTR banking_transfers; the venture half is banking_service.rb create_or_find_by! never updating"
metadata:
  type: reference
---

Half of the CPTR backdate trap is venture code: `banking_service.rb:57` uses `create_or_find_by!`, which never updates an existing row, so a re-delivered transfer keeps the stale values.

Primary write-up is in the treasury scope: `cptr-banking-transfer-sync-backdate-trap.md`.
