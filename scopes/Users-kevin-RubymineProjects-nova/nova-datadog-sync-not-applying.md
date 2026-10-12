---
name: nova-datadog-sync-not-applying
description: "FIXED 2026-09-30 by #10636 (Andrew Mahon: CI apply with three-way conflict detection). Historical: apply was dead 2026-09-16 to 09-30; --pull could not recover UI-made orphans."
metadata:
  node_type: memory
  type: project
  originSessionId: 0a933a67-0831-456c-b641-8d1c79dac7dc
  modified: 2026-10-01T06:05:54.162Z
---

**RESOLVED 2026-09-30:** #10636 (`690f161ecb`, Andrew Mahon) applies `ops/datadog` from CI with
three-way conflict detection. Everything below is historical; re-verify the orphan/`--pull` notes
against the new sync before relying on them.

As of 2026-09-25, merging a monitor JSON to `ops/datadog/monitors/` on nova `main` does **not**
create or update anything in Datadog. Verify before promising anyone an alert is live.

**Last successful apply: 2026-09-16 ~17:10 PDT.** Timeline (merge time → live in Datadog):

- #10180, 9/16 10:32 → `dataroom-self-advised-faq-sync` created 9/16 17:10 ✅
- #10203, 9/16 19:19 (message edit to that same monitor) → never applied ❌
- #10181, 9/16 19:35 → both `[dataroom] Venture…` monitors absent ❌
- #10470, 9/24 14:55 → `[nova-graph] External bank reference authorization denial` absent ❌

**Cause unconfirmed.** Red `main` is *not* it — the last 6 main commits were 5×success. The
apply is gated on `DD_APPLY_ENABLED` being set on the Buildkite agents (`.buildkite/pipeline.rb:908`,
`datadog_apply_skip_reason`); confirming needs a Buildkite log from a `main` build that touched
`ops/datadog/`.

**The canary can't catch this.** `nova-datadog-canary` was created once in June and is deliberately
inert, so it stays green whether the apply runs or not. It proves the sync worked once, not that it
works now.

**People are routing around it.** Griffin hand-made `[nova] Distribution payment FSM event failed`
in the UI on 9/18 *with* a pasted `[managed-by:nova-repo] [dd-resource:nova-fsm-event-failed]`
marker and no backing file — GitHub code search for that slug returns 0. Teddy hand-made
`[nova-temporal] Data room campaign sync failed` on 9/22 with no marker at all. So a
`[managed-by:nova-repo]` marker in a live monitor's message is **not** evidence a file exists.

**`--pull` will not fix the drift, and reverts work.** `pullResources` iterates the plan, and
`planAll` builds that from the local files (`ops/datadog/sync.mjs:454-474`, `readdir` at `:214`):

- A live monitor with no local file never enters the plan, so pull **cannot discover orphans**.
  Griffin's monitor has to be hand-written (export the JSON from the UI) before a pull can normalize it.
- Where local and live both exist and live is *older*, pull rewrites the local file backwards — today
  it would revert #10203's message edit.
- Resources not in the org are correctly skipped (`would be CREATE`).

Right order: fix the apply → let the pending PRs land → then adopt the UI orphans.

Related: [[nova-matchmaking-fsm-observability]]

## CONFIRMED 2026-09-25 — supersedes the timeline above

Buildkite renders the reason on the step, on build 51369 (#10470, 9/24, which **passed**):
`Datadog: apply` / `DD_APPLY_ENABLED not set` — `datadog_apply_skip_reason` at
`.buildkite/pipeline.rb:909`. The step is **skipped**, not failed, so the build stays green.

**There was no 9/16 regression.** Build 48179 (#9828, 9/01) shows the Nova Datadog group running
1/1 step — validate only — so it was already skipping a fortnight earlier. Build 50017 (#10180,
9/16) **failed**, so the monitor appearing 6.5h after that merge was hand-made, not applied.
Accurate statement: **no monitor JSON in nova has ever reached Datadog through the pipeline.**

**It was deliberate.** #nova-eng 2026-07-15,
https://angellist.slack.com/archives/C09MU7S0RA4/p1784151322059349 — Andrew Mahon calls the tooling
"largely unused"; Kevin Marlow reports the same symptom ("still passing dry-run", no DD_API_KEY in
1Password); Tibi Egyed identifies `DD_APPLY_ENABLED` but not where it goes; Andrew: *"the pipeline
isn't totally ready to go yet. some unsolved questions around syncing changes made in UI back to
code"* + *"i'll loop back here with a concrete next step in a bit."* He never did.

**The stated blocker shipped in that same message** — `--pull` (#8900) and `--drift-check` (#8903).
So the reason for the hold no longer applies. This is an unfinished rollout to resume with Andrew,
not a bug to fix. Open questions for him: where `DD_APPLY_ENABLED` belongs, and whether
`DD_API_KEY`/`DD_APP_KEY` were ever provisioned for the agents.

Tracked as BANK-2165. Caution: the first apply reconciles ~35 files at once, most still carrying
placeholder routing/thresholds — read a `--dry-run` plan first.
