---
name: bank-1678-interchange-sandbox-probe
description: BANK-1678 sandbox GET-probe results (2026-10-05) — sweep plan ids, program config lacks ORGANIZATION, 1h JWT, events path/pagination quirks
metadata:
  type: project
---

2026-10-05 read-only probe of sandbox.api.interchange.com (creds in ~/.interchange/credentials work; program ANGL `031pQ8iMdPhiS0Iisn8Ie0`). Extends [[mmf-interchange-integration]].

- Sweep plans (all ACTIVE, JPMAM, 100% single fund): OGSXX govt `033Z9key7TFK5je2cuYM03`, IJTXX `031Q1Tmrcs2vkealeiRIL3`, test `033Vf5K0LNKUsjJPpghnAF`. Program default NOT discoverable via API.
- Program created-event showed no ORGANIZATION — STALE: 2026-10-06 an ORGANIZATION (LLC_PARTNERSHIP) account create succeeded with OGSXX sweepPlanId. Acct `034BpTJEIHbujd3eMOokAB` stuck PENDING on `clearingManualApproval` — clearing-tenant-only evidence; Interchange must approve. Account APPROVED by Interchange 2026-10-07. API `clearingControls.instantDeposit.canUseAdvance: true` is only the clearing ceiling — portal Controls shows Allow Advances OFF via Program Config (effective). Advance-reversal risk is moot; I wrongly called it live before checking the portal. EntityType enum has no TRUST.
- JWT TTL is 1h on sandbox, docs claim 12h — refresh off `exp`.
- Events poll: live path `/events/v1/receive` (documented `/ixm/events/v1/receive` 404s); nextToken never null at head — stop on empty page; history back to 2025-12-10.
- Harness: scratchpad `probe.sh` / `pull_events.rb` (GET-only, never prints token).

**Why:** gates 2/3/6 blocked on Interchange approving the org account; was pending Kevin's call on asking Interchange vs trying an ORGANIZATION account create.
**How to apply:** harness `ix.rb` + step*.rb in pulse-2 scratchpad; check account status before resuming funding/sweep steps.

2026-10-07 gate 2 run: source `034Bv4YFUUJNhNYMCs5jBU`, $1,000 ACH pull `034Bv4Z3vnarxv113lwhlo` → SUCCESS in ~1s and credited as SETTLED cash immediately (Transaction settleDate 10-06) though transfer estimatedSettleDate = 10-08; no deposit advance. Return-after-sweep is the live gate-3 vector — ask Interchange if prod does the same. Banksim (`/exc/banksim/v1/sandbox/{settle,return,reject,reverse}/:transferId`, inbound-wire, inbound-ach-push) drives outcomes. Sweep expected at 4:30pm ET cutoff; poller `wait_sweep.rb`. Kevin has NOT yet approved the banksim Return test.

2026-10-07 later: return-before-sweep clean (new Transaction, same fundingId, isReverse:true). Billing 412 "no billing account for program". Account-number create 400 "not enabled by clearing controls". 2nd org acct `034Bvodjm734e6pNMjj4qj` (orders on, sweeps off) AUTO-approved. MMF order 403 "restricted to clearing users" → explicit-order track BLOCKED. Arti doc `interchange-sandbox-map` v3 is canonical; Kevin moved BANK-1679 to another session but wants remaining gates resolved here. Kevin OK'd sandbox banksim tests.

2026-10-07 AM: NEGATIVE CASH CONFIRMED on orders acct: pull $500 (034BSpv4eSVgdVwBIGXqIe) SUCCESS instantly → ACH push $1,500 (034BSpABt0OsBNIGsFGp51) SUCCESS instantly (withdrew unsettled ACH funds) → banksim return of pull → settled cash −$500, no hold. Treasury must guard (don't forward pulled cash before ACH return window). No API/banksim sweep trigger; portal session expired (don't log in for Kevin).

2026-10-07 17:20Z: Interchange manually triggered sweep (Kevin asked them). GATE 2 RESOLVED: one Transaction, deltas cash −1000 / OGSXX +1000 (sweepAsset:true), detail `ixc.sweeps.clearing.v1.SweepsTransaction` orderType PURCHASE fillPrice 1 adapterOrderId confirmTime. sweptBalance counts toward availableToWithdraw. Return of swept pull → cash −1000, swept 1000 untouched, availableToWithdraw 0 (no auto-redeem). Poller `wait_redeem.rb` watching whether next sweep cycle cures it. Arti doc NOT yet updated with gate 2/3 final results.

2026-10-07 20:35Z: 4:30pm cutoff sweep auto-REDEEMed 1000 OGSXX to cure the −1000 cash → cash 0, swept 0. Gates 1–5 RESOLVED, 6 BLOCKED (MMF orders restricted to clearing users). Arti v4 published (sha 30f9bc54…). Orders acct still at −$500. Offered Kevin: update BANK-1678 description + close, split gate 6 into its own issue — awaiting answer.

2026-10-07 21:06Z: BANK-1678 moved to Done with per-gate verdicts + Arti link. Gate 6 split to BANK-2240 (blocks BANK-1680). Remaining Interchange questions live in the Arti doc.

Status (2026-10-14, unverified, carried from the index line): probe done; gate 6 moved to BANK-2240.
