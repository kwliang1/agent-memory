---
name: handoff-usage-phase-followups
description: "PR 1 (usage phase attribution) is MERGED and deployed — this is the handoff list for the three follow-ups Kevin is giving to a new session"
metadata:
  type: project
---

**PR 1 is DONE.** [#409](https://github.com/sf8193/hydra/pull/409) merged 2026-09-29 as `0f8b447`, pulled into `~/RubymineProjects/hydra`, daemon restarted onto it (pid 49707), raindrop live with zero POST failures. `daemon/usage-phase.ts` ships `phase` (plan/execute/review/report) and `phaseSource` (protocol/tools/latched) on `hydra.session.usage`. History and traps: [[wip-usage-phase-attribution]].

Kevin is handing the three items below to a new session (2026-09-29). They were explicitly **held**, not forgotten.

## 1. Mutation round-8 leftovers — 3 tests + 1 deletion, no source change

Found by a mutation reviewer against `4a53cbe`; all still true on `main`.

- **Highest value.** Deleting the **entire `if`** at the Codex short-circuit in `defaultUsageFor` (`daemon/raindrop.ts`, the `!r.phases` branch) passes the whole suite. Both single-term mutants are caught; the conjunction as a unit is not, because **no Codex test ever observes `defaultUsageFor` returning `[]`** — the phase fork has three such tests, the Codex fork zero. Live consequence if it regresses: an idle Codex session emits an all-zero-delta event every 60s forever, and one that has spent nothing emits a phantom baseline every tick. **This is the second one-sided guard on the same fork** — round 7 was the resend term. See the collapse argument below.
- The sweep's release of a **Codex** delivered baseline is untested: narrowing the iteration to `deliveredPhaseTotals.keys()` alone survives. A Codex session leaving `knownSessionIds` without a death event leaks its `deliveredTotals` entry for the daemon's life.
- A **death with an unresolvable user** has no test; `if (bodies) await dispatch(...)` → `dispatch(..., bodies ?? [])` survives, i.e. an empty POST per death while raindrop is misconfigured.
- **Delete** `nextLatch is latchVote plus the carry` (`daemon/__tests__/usage-phase.test.ts`). It computes its expectation from `latchVote`, the function under test, so a bug cancels on both sides — zero mutation score. Fifth vacuous assertion removed from this work; the three sibling closed-set tests are real, keep them.

## 2. Two follow-ups promised to sf8193 in PR review threads

Both were answered in-thread with "logged as a follow-up" — so they are owed, not optional.

- **Register `protocol-runner.ts` in `scripts/gen-topology.ts`'s `LAYER_CONFIG`.** `LAYER_CONFIG` is an allowlist (`knownPaths = new Set(Object.keys(LAYER_CONFIG))`), so an unregistered module is silently excluded and regenerating shows **no diff** — that is the symptom, not the all-clear. 18 of 59 `daemon/*.ts` are uncurated. Registering a 1,700-line module pulls its whole edge set into the docs, so expect a large diff.
- **Thread the protocol role through the registry instead of importing the orchestration engine into telemetry.** `raindrop.ts` imports `protocol-runner.ts` purely to read one role string, and `registerRunnerHooks()` runs at **import time** (`protocol-runner.ts:1725`). No lighter seam exists today: `SessionFacts` has no role field and `SessionInfo`'s two `role` fields are a different concept (`main|worker`, `owner|member`). Proper fix is protocol-runner *pushing* role into the registry, telemetry reading it.

**Related, and Kevin has ruled on it — do not reopen without new evidence.** Three independent reviewers asked to collapse `deliveredTotals` + `deliveredPhaseTotals` into one `PhaseTotals`-shaped map. Kevin's decision 2026-09-29: *"intentionally leave it to claude for now"* — phase attribution stays Claude-only, and giving Codex a phase-shaped baseline would assert a phase concept it does not have. The duplication is **not free** (it is the root cause of item 1's repeat), but the answer is tests, not reshaping, until Codex gains real phase attribution.

## 3. PR 2 — drain subagent transcripts (never started)

`transcriptPathFor()` returns one path; subagent transcripts sit at `<projectsRoot>/<dir>/<sessionId>/subagents/agent-*.jsonl` and are never read. Design already settled with Kevin: subagents inherit the parent's phase at spawn. `UsageCursor` is singular, so N files need N cursors — that plus fold-into-parent vs own-event is the design work.

**A double-count worry I raised and then disproved — do not re-derive it.** `"isSidechain":true` appears in **0 main transcripts** and in 2406 subagent files (verified 2026-09-29). An earlier reviewer claimed sidechain turns are 5.5% of main-transcript spend and ~40% of the `plan` bucket; it had scanned `subagents/*.jsonl` alongside main transcripts. So draining those files does **not** double-count.

Also open from PR 1's known limits, if PR 2 reworks the cursor: a turn open at a read boundary is attributed at the phase it was leaving, and `report` alone loses 5–12% of its own bucket one-directionally because it has no latch to recover on. Retro-attribution emits a **negative delta** once the baseline is delivered — that is why it was accepted rather than fixed.
