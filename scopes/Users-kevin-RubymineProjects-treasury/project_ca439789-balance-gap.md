---
name: project_ca439789-balance-gap
description: CA 439789 / IVA 439790 balance check reads treasury +$20,239.42 on SA 518425 — three stuck bank legs; repair task in treasury#9097 (draft, 2026-10-08), not yet run
metadata:
  type: project
---

Diagnosed 2026-10-08 from prod read console. Gap on SA 518425 (Fifth Third), carried from SA 498080 through the 9/17 migration.

- **$10,035.73 at SVB 498133** — Transfer 237747 forwarded TP→SVB for SEK OW 134282 two days after it was cancelled; never forwarded back.
- **$10,196.69 at on-core 515386** — Transfer 242668 moved IVA→on-core; LE 5840858 "Undo…" credited it back ledger-only.
- **$8.00 SVB excess on FX OW 135949** — sent $11,476.50 (TAG $11,471.46 + shortfall $5.04), wire completed at $11,468.50. BUT PaperTrail shows amount set to $11,476.50 with no later version; the row reads $11,468.50 (edited out-of-band), completed via console 9/23. Whether SVB debited $11,468.50 is unverified — PR makes the SVB portal check a before-merge prerequisite.
- **−$1.00 unexplained**, appeared 9/10–9/19; out of scope, next to chase.

treasury#9097 (`Maintenance::RepairCa439789BalanceCheckGapTask`) does all three legs: leg 2 is a USER_OVERRIDE transfer with `ledger_entry:` reuse + `skip_transfer_chain_creation` (on-core cash < amount, so the mirror chain would otherwise fire); leg 3 mirrors the FX recon's SVB_EXCESS shape. SA 515386 is never balance-checked. Worktree `~/RubymineProjects/treasury-ca439789`.

**Why:** money movement awaiting SVB-portal checks and Kevin's merge. **How to apply:** don't run the task live until both SVB checks pass; a failed leg is not retried by re-run (token consumed). Related: [[treasury-three-balance-functions]], [[ach-pull-cross-ca-sub-landing]], [[treasury-repair-task-gotchas]].

**Update 2026-10-08 — the −$1 is FOUND:** IncomingWire 313171 ($1.00 ACH credit, "SWAP COMMERCE LT Rankai AI", sub 498080, still `provisioned`, balance $1). Its ledger flip-flopped received/"returned" (ledger-only, no bank movement) 7/09–7/23; residual tracked it exactly. After the 9/17 migration the IW stayed on inactive 498080, so `incoming_wire_adjustment` (active-sub only) dropped its $1 while the real dollar was swept to 518425. Fix = assign or truly return the IW (Kevin's call); re-pointing its sub only hides it.
**Method that worked:** quiet balance-check records only (ip=0, no details), residual = diff − known legs active at that time; first quiet −100 bracketed the day, then list that window's LEs. Item-level bank↔ledger matching since 9/01 found nothing because the culprit predated it. Also: Kevin's write console pod (`console-write-kevin.liang-0`) is reachable via `al console exec -a treasury -e prod -w` even when GlobalConsoleWriters elevation lapses — used read-only for TP GETs.

**Update 2026-10-08 (dry run in prod write console, outer rollback):** legs 1 and 3 pass; **leg 2 correctly REFUSED** — on-core 515386 TP balance $9,933.26 == its ledger. On-core bank: +10,266.65 (8/28) → −10,266.65 back to fund (8/31, T241681) → +10,196.69 (9/01, T242668) funded the real Polhem wire −10,161.97 (9/01) → +9,828.58 FX return (9/11). So the fund genuinely spent the $10,196.69; the ledger never debited it (LE 5839164 and undo 5840858 both rev=0). Leg 2 must become a LEDGER correction, not a bank move — pending Kevin.

**Update 2026-10-08 (night):** On-core ledger leg is PR treasury#9102 (gate passed; Cursor findings declined with prod evidence). Finance (Denis Barushev, #C06U97BKHN2 thread 1791506548.977669) said **keep the run date** for the $10,196.69 CPTR outflow — do NOT run the CPTR backdate runbook. Kevin runs all three legs "tomorrow" (10/09) after #9102 merges.

**Update 2026-10-09:** Kevin ran all three task legs plus the IW 313171 fix. LE 5926656 deposited the $1. T291414 and T291416 (SVB → 518425) were `submitted` at 17:00 UTC, and live internal $4,029,379.64 equals the 16:40 bank figure. Denis confirmed CPTR picked them up. The competing $1 was IW 313170 (same Rankai AI sender, to CA 365783), which was returned cleanly on 7/17.

**Update 2026-10-09:** Kevin ran all three task legs plus the IW 313171 fix. LE 5926656 deposited the $1. T291414 and T291416 (SVB → 518425) were `submitted` at 17:00 UTC, and live internal $4,029,379.64 equals the 16:40 bank figure. Denis confirmed CPTR picked them up. The competing $1 was IW 313170 (same Rankai AI sender, to CA 365783), which was returned cleanly on 7/17.

Status (2026-10-14): #9097 and #9102 merged 2026-10-09 (checked with gh); the index line said all four legs ran that day.
