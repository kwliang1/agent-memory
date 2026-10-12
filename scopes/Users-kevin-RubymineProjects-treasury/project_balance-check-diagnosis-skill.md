---
name: project_balance-check-diagnosis-skill
description: treasury repo skill `.claude/skills/balance-check-diagnosis` (branch kevinliang/balance-check-diagnosis-skill, 2026-10-09) — read-only prod runner that ties a balance-check gap to items; use it first on any balance-check question
metadata:
  type: project
---

Built 2026-10-09 from the CA 439789 investigation, at Kevin's request, in the treasury repo (not ~/.claude/skills; Kevin was explicit about that).
`scripts/diagnose.rb <ca id|uuid> [lookback_days]` and `scripts/window.rb <ca> <from> <to>`, run via `al console push/exec -a treasury -e prod`.

**Validated:** CA 365783 (uuid 7faec860…, lookback 300) reproduces the July forensic to the cent: OW 119256 and OW 119116 are SVB strands, each matching a quiet step; −594.73 is FX dust; −5,187.69 is unexplained. On CA 439789 the step history shows −1 (7/17), +10,036.73 (8/31), +10,196.69 (9/03) and +7 (9/25). The legs themselves were already repaired on 10/09.

**Lessons baked in:** older SVB forwards are ledger-only (no Transfer rows), so detect via LEs with requester OW. `revised_amount_cents: nil` + `revised_ledger_entry_id` marks a revision entry; skip it. A step of +X followed by −X is noise. An exact step match within 14 days beats the "a later quiet read was smaller" offset heuristic. `al console exec` passes args as one string, hence `ARGV.flat_map(&:split)`.

Related: [[project_ca439789-balance-gap]], [[treasury-three-balance-functions]], [[ivc-phantom-overcredit-migration]].

**Update 2026-10-09:** Pushed as treasury#9116 (commit 36ca971c1) after 13 gate rounds; Kevin said "push it as-is" before 2 clean rounds. Round 10 he chose to SIMPLIFY section 6: inactive-sub IWs are always `check`, listed with FUNDS_MIGRATIONs from that sub to non-SVB family subs (FUNDS_MIGRATION also covers routine SVB/TAG forwards — filter by to_sub). Traps found: `fund_migration_transfers` aliases the join as `metadata`; LEs don't touch wire updated_at, so stuck IWs/OWs age out of a lookback; V2 transfers post LEs only on completion, so pending legs must be handled separately and NOT folded into nets; auto-resolve runs on any failing active-sub check, not only when the IW itself fails it. Deferred wording nits listed in ~/.claude/review-findings/treasury/kevinliang-balance-check-diagnosis-skill/1[0-3]-*.md.
