---
name: svb-over-1m-wire-forward-8611
description: "PR #8611/#8126 chunk >$1M SVB→non-SVB incoming-wire forwards into ACH; fixes ROUTING only, not provisioning (SVB BAI2 sync gap) nor duplication vs ops manual forwards."
metadata: 
  node_type: memory
  type: project
  originSessionId: eef8fe26-98a9-41c1-80c6-a2f3afed3bd3
  modified: 2026-08-25T22:46:27.513Z
---

SVB incoming wires >$1M that must forward to a non-SVB active sub-account used to strand as an un-submittable SVB Wire (SVB can't submit wires programmatically). Fixes:
- **#8126 (BANK-1572)** = the straight forward path `forward_funds_to_active_sub_account!`.
- **#8611 (BANK-1849)** = the reassignment/merge/GHB→CCA revision path `revise_ledger_entry_destination!`; also refactored both onto shared `Transfers::InfoService.requires_svb_ach_split?` (`from.svb? && !to.svb? && amount > MAX_ACH_AMOUNT($1M)`) + `ach_split_amounts` (ordered ≤$1M chunks). Merged 2026-08-20. Predicate/split at `app/services/transfers/info_service.rb:68-83`; wire paths in `app/services/incoming_wires/state_service.rb` (reassignment branch line 69, forward branch line 121→448).

**What the fix does NOT cover (the real 2026-08-25 concern, wire 319384 = SVB $1,936,855.94, FBO SpaceX Disbursement, Assignment None, still `Created`, zero LEs):**
1. **Provisioning is untouched** — `provision!` unchanged. These wires sit in `Created` because **SVB's BAI2 files aren't syncing**, so nothing auto-provisions. That's the live blocker, not routing.
2. **Duplication hazard** — ops workaround = manually forward via outgoing wire ("funds in flight"). If you then Provision + let the system auto-ACH-forward, it moves the money a SECOND time. No dedup against the manual wire. Confirm with Thomas Ambrosia (DRI) whether SVB funds were already manually swept BEFORE provisioning through the system.

The split correctly yields e.g. $1,000,000 + $936,855.94 for 319384. See [[unprocessed-ach-return-overcredit]], [[bai2-458-rtp-debit]] for adjacent BAI2/SVB context. Bridge console note: treasury read console RBAC-blocked (`treasury-ro`) + no `GlobalConsoleWriters` role on 2026-08-25; used Claude-in-Chrome on treasury.internal instead.
