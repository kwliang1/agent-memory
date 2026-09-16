---
name: treasury-fatal-incident-automation-gap
description: "Why treasury fatal exceptions sometimes create NO incident.io incident — Sentry rule #1138388's frequency/first-seen conditions blind-spot low-frequency daily cron failures (e.g. BAI2)."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 56234658-eb21-4ee3-abde-52872ac45e49
  modified: 2026-08-19T18:08:07.399Z
---

Treasury→incident.io auto-incident path: `ErrorTracker.critical(e)` (treasury/lib/error_tracker.rb, sets Sentry level=**fatal**) → Sentry issue-alert rule **"Treasury Fatal Exceptions to Incident.io"** (#1138388, project treasury/6710621) → incident.io alert source **"Sentry Banking Alerts"** (01JZW4GGGT9HSMJ36R84Z33W1G) → alert route **"Banking alerts"** (01JZW4VD72...) → incident.

**The gap (investigated 2026-08-19 for Dan Cetlin/Kevin):** rule #1138388 fires only when a fatal issue is **first-seen OR regressed OR reappeared OR seen >1×/day** (trigger logic `any-short`; action filter `level==50/fatal`, env=production, 30-min interval). Any fatal exception that is **already an open/unresolved Sentry issue AND recurs ≤1×/day** matches NONE of the four → no alert → no incident. Exactly the profile of **daily cron/batch failures**. Once such an issue is open it's silent forever until someone resolves it (then only a regression re-alerts).

Concrete case: `TREASURY-67B` `Bai2File::Bai2ProcessingError: Could not find a matching reversed IncomingWire` (daily bai2 cron: `Bai2PreviousDaySyncFiles::ProcessingService#process_for_date!` → `WireProcessingService.process_reversed_incoming_wires!:69`), fatal, first-seen 2026-07-10, ~1/day → no incident on 8/19 failure. Contrast: Layer2 `$992.57` `TREASURY-5WX` (also ongoing/unresolved but fires many/day) → cleared >1/day → auto-created INC-5489.

Note: `treasury-cron-error-spike` DD monitor won't backstop this (needs >20 err/10min). The `:alert-flashing: BAI2 File Failed to Process` Slack ping is a SEPARATE Flowdash workflow (treasury `lib/flowdash/workflow/banking/bai2_file_processing.rb` upserts a task via `Flowdash::Client`), not the incident path.

Fix options: (1) deterministic incident on the failure path — new Flowdash `Step::IncidentIo` (flowdash repo, calls POST api.incident.io/v2/incidents) wired to the BAI2 workflow's failure automation, or a direct incident.io call from the cron rescue [what Dan was building]; (2) change #1138388 frequency ">1 in 1d" → ">0 in 1d"; (3) resolve TREASURY-67B + fix the reversed-wire mismatch.
