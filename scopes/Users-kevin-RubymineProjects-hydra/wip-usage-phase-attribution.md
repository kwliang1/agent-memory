---
name: wip-usage-phase-attribution
description: "UNPUSHED branch kevinliang/usage-phase-attribution (PR 1 of 2, phase on hydra.session.usage) — rebased onto main, green, review gate in progress"
metadata:
  node_type: memory
  type: project
  originSessionId: a636870c-16f2-45ab-9c88-75ee39edfb91
  modified: 2026-09-28T07:00:00.000Z
---

**State as of 2026-09-28.** Branch `kevinliang/usage-phase-attribution`, commit `e3106d4`, signed, **never pushed, no PR exists**. **Rebased onto `76ca8eb`** (the 30-commit drift that blocked the previous session is resolved). Worktree `~/RubymineProjects/.worktrees/hydra-comet` (the old `hydra-atlas` one was torn down; only the branch ref survived).

Green: 2367 tests pass, all three entry points build, `tsc` at 56 = `main`'s baseline, zero added. 10 files, +939/−112.

**What it does.** Adds `phase` (plan/execute/review/report) and `phaseSource` (protocol/tools) to `hydra.session.usage`. Phase is read from tool names on the lines `usage.ts` already parses and **latches** across drains. New file `daemon/usage-phase.ts` (pure classifier). A tick and the death read both emit one event per phase through one `usageBodies()` builder that refuses a partial set.

**How the rebase resolved the adapter question.** `6a1d4bc` made `UsageReading.cursor` an **opaque `unknown`**, so `raindrop.ts` structurally cannot read phase off the cursor any more — casting it back would break on a Codex session. So the phase split moved to the provider seam:
- `UsageReading` gains `phases?: { totals: PhaseTotals; current: UsagePhase }` (`engines/engine-adapter.ts`). Nested so "split and current phase" can only arrive together. Claude's adapter fills it from the drain; Codex leaves it undefined.
- `SessionUsage.phase`/`phaseSource`/`phaseTotals` are a **union — all three or none**. A Codex event **omits** them rather than defaulting to `plan`.
- The delivered baseline is **two maps**, `deliveredTotals` (TokenTotals) and `deliveredPhaseTotals` (PhaseTotals), **never both holding one session** because a session keeps one adapter for life. `forgetDelivered`/`bankDelivered` are the only writers.
- `usageEventId(sessionId, stamp, phase?)` keeps the old `:usage:<stamp>` form for a phase-less row, so **Codex event ids are unchanged**; only phase rows take `:u<stamp>:rev`.

**Review gate: 0 of 2 clean rounds.** Rounds 1 and 2 (findings fixed, amended) predate the rebase, so they do not count toward the current code. Round 3 spawned 2026-09-28 with 3 reviewers: correctness, ops blast-radius, test/mutation (the last in its own worktree).

**Things worth not rediscovering:**
- Tool names must be read BEFORE the usage-envelope dedupe. A turn writes one line per content block and the `tool_use` blocks sit on the lines `usage.ts` dedupes away (~93% of multi-line turns). See [[transcript-phase-classification]].
- A **per-window** tool rule collapses at the 60s tick (98% "plan"). The latch is the whole design.
- `phaseSource: 'latched'` was implemented in round 1 and **removed** in round 2: it compared lifetime buckets on a window-scoped row, and its `flat()` summed `cacheReadTokens` (94% of a real transcript) so it measured context growth, not latching. Reporting the latched fraction honestly needs a second delivered baseline — that is PR 2's.
- Event ids use a 3-letter phase code so **every phase's id is the same length**; that is what makes the all-or-nothing batch guard unreachable rather than lucky. The old `:usage:<at>:<phase>` form put `execute` at exactly the 64-char cap.
- A `Record<string, …>` indexed by an open runtime string returns truthy `Object.prototype` members. Bit this twice (protocol names, extra-property gates).
- **`readUsageDelta` clones `phaseTotals` on every read**, which is what makes the adapter's `clonePhaseTotals` at the seam belt-and-braces rather than load-bearing. A mutation that aliases the cursor's live buckets survived the whole suite, so that invariant is now pinned directly in `usage.test.ts` ("a read never hands back the buckets the cursor it was given holds"). Without it, the banked baseline tracks the live cursor and every delta silently settles at zero.
- KNOWN LIMIT left in: a turn open at a read boundary is attributed at the phase it was leaving (~8% of one phase). Deferring the open turn was tried and is **worse** — an idle session's last turn never reports. Fix is to carry the open turn on the cursor; belongs to PR 2.

**PR 2 (never started):** drain `<projectsRoot>/<dir>/<sessionId>/subagents/agent-*.jsonl`. Design decided with Kevin: subagents inherit the parent's phase at spawn (delegation moves the parent to `review` on the line that carries it, so inheritance is constant). Plus the self-consistency check (re-read from offset 0, compare to the cursor, emit drift). Plan artifact: https://claude.ai/artifact/8thLqkjy9CvzEqiDSNjie7

---

**ROUND 3 + 4 (2026-09-28, session comet).** Commit `a5f395e`, rebased onto `76ca8eb`, signed, green (2373 pass, tsc 56 = baseline). Gate still 0 of 2 — round 4 had 1 clean reviewer of 3.

**The structural finding, and the reason this stalled.** The tool-name heuristic does not fit: each round fixes one bucket and the error moves to the next. Measured on 199 transcripts / 22.2B tokens by an independent replay of the production classifier:
- `report` was 45–83% of spend (runs of 135 Bash turns) → **fixed** by making `report` momentary (`LatchPhase = Exclude<UsagePhase,'report'>`); now 5.5–11.7%.
- `review` is now 44% of emitted spend with **94.3% latch carryover**, 75% of it on `Bash`-only turns, longest run **425 turns**. ~48% of it is latched by a *search* delegation (`general-purpose`/`Explore`/unset), not a review one = **20.6% of ALL fleet spend** mislabelled.
- `plan` **can never be voted** — `nextLatch` has no branch returning it — yet every non-protocol row is stamped `phaseSource: 'tools'`. Structurally false.
- 17 sessions spawned with the review protocol's **Critic mandate** (ground truth = review) bill **71.5% `plan`**; 12 of 17 bill 100% `plan`.

**The proposed inversion (awaiting Kevin's direction call).** The daemon already holds the facts it is inferring: `getProtocolContext()` returns `role` + `phase`, the spawn mandate is in `~/.claude/channels/slack/spawn-logs/`, `sessionType` is in the registry. Use facts first, tool inference as a labelled fallback, and add a `phaseSource` value for "carried, nothing voted in this window".

**Confirmed defect, not yet fixed — `protocolPhaseForName` keys off the protocol NAME.** `protocols/review.ts:26` `apply_changes` has `actor: 'owner'` (the owner applying fixes) and is force-billed `review` with `phaseSource: 'protocol'`, the highest-confidence label. `cleanup` (owner posts the summary) likewise — it is `report`. Mirror gap: `protocols/build.ts:18` `reviewing` has `actor: 'critic'` but gets no force because the protocol is named `build`. Planned fix: key off `role === 'critic'` (exists in both review.ts and build.ts), dropping the name lookup entirely. Also: `runs` is in-memory (`protocol-runner.ts:82`), so a daemon restart mid-run silently relabels critic spend from review/protocol to plan/tools.

**Verified CLEAN across rounds 3–4, do not re-litigate:**
- Absolute token counters are **exact**: 199/199 transcripts, three independent cross-checks (independent unique-id sum, non-adjacent dedupe escapes = 0, 60s-window tick replay). Only the *split* is unreliable.
- Removing `clonePhaseTotals` from `claude-engine.ts:usageTotals` is **safe** — `readUsageDelta` clones above every early return. Proved twice (runtime probe + 10 existing tests fail under the alias mutation). The invariant is pinned by `usage.test.ts` "a read never hands back the buckets the cursor it was given holds".
- `REPORT_TOOL`'s regex anchors are exact across 120 transcripts, zero false positives (`mcp__arti__reply_to_comment` correctly excluded).
- Conservation `sum(phaseTotals) === totals` holds; the `sessionBase` short-circuit is safe because per-phase totals are monotonic between base and read.
- Round 4 mutation reviewer: **21 mutations, all caught**, including the exact round-3 regression (`const phase = latch`).

**Declined with reasoning:** curating `usage-phase.ts` into `docs/topology.mmd` (generator produces no diff; editorial); `getProtocolContext` over-building (cost nil); deleting `nextLatch`'s repair branch (guards an unchecked `prev as UsageCursor` cast); collapsing the two delivered maps (reviewers call it a judgment call, and "omit don't fake" for Codex is a real constraint).

**Known gaps if this ships as-is:** Codex rows carry no `phase` and no sentinel, so a phase-grouped dashboard drops them silently. Bash-authored edits (`cat >`, `sed -i`) never vote `execute` — 0.6% of fleet spend. Cold-start window's spend appears in no `delta*` (pre-existing, ~0.9–4.5%).

---

**ROUND 5 (2026-09-28, session comet → atlas).** Commit **`b05afe5`**, signed, worktree `~/RubymineProjects/.worktrees/hydra-comet` clean. Verified by atlas 2026-09-28 16:20 UTC: **2383 pass / 5 skip / 0 fail**, all three entry points build, `tsc` 56 = `main`'s baseline. Still never pushed, still no PR. **Gate 0 of 2.**

**Option 1 shipped in `b05afe5`** (Kevin picked it over folding the redesign in or shipping totals only):
- `phaseSource` gains **`latched`** — `USAGE_PHASE_SOURCES = ['protocol','tools','latched']`. A row now says whether a turn *in that window* voted its phase, or whether it was carried. `voted: readonly UsagePhase[]` rides `UsageCursor` and is unioned across `drainUsage`'s passes; `defaultUsageFor` sets `phaseSource: voted.has(phase) ? 'tools' : 'latched'`.
- **`protocolPhaseForRole(role)` replaces the name lookup** — `role === 'critic' ? 'review' : undefined`. Fixes both directions: the `review` protocol's `apply_changes` (actor `owner`) stops force-billing `review` under the highest-confidence label, and `build`'s `reviewing` critic phase gets labelled for the first time.
- `advance` added to `REPORT_TOOL` (it posts the deliverable to the thread verbatim).
- 7 mutations run, 7 caught.

**The honest production number is ~29% measured / ~71% carried**, not the 69% a first run suggested. That run used 40-turn windows; a real 60s tick is ~5 turns. At window=5 → **28.7%**, which lands on round 4's independent 29.1% from actual 60s-tick simulation. Two methods agreeing. `plan` is **0.0% measured** (latchVote has no branch returning it) and `report` is **100% measured** — both window-independent, so they are the proof the mechanism works.

**ROUND 5 NEVER PRODUCED A VERDICT.** All three reviewers died 6 minutes after spawn with `Not logged in · Please run /login` (2026-09-28 13:55 UTC); the same auth expiry silenced comet itself. Zero findings exist from that round — it must be re-run from scratch, not counted. See [[feedback_review_round_can_die_on_auth]]. atlas relaunched it 16:20 UTC.

**Left to do:** two successive clean rounds → push → open PR 1 (body needs the ~29%/71% split, the `Agent`→`review` search bias, and Codex rows carrying no phase). Then Kevin's call on the known gaps, the sharpest being that **Codex rows carry no `phase` and no sentinel**, so a phase-grouped dashboard drops them silently rather than showing them as unknown. Then PR 2, never started.

---

**ROUND 5 FINDINGS AND FIX PASS (2026-09-28, session atlas).** Re-ran round 5 after the auth deaths. All three reviewers had findings. Fixed and amended to **`1080386`**, signed, green: 2387 pass (+4), tsc 56 = baseline, 3 entry points, topology no diff.

**Finding, found independently by two reviewers: `phaseSource` decays `tools` → `latched` on a retried window.** `voted` is scoped to the READ; `delta` is scoped to the DELIVERY, and `deliveredPhaseTotals` only advances inside `.then(ok => …)`. A failed POST leaves the baseline behind while the cursor advances, so the next tick reports tokens whose votes are gone. The protocol variant is worse: `deps.protocolPhaseFor` is re-read at retry time, so a dropped tick inside a review run ships as `execute`.
**Resolved as comments-only, on measurement:** the daemon log (`~/hydra-slack-daemon.log`, Sep 9 → Sep 28, 40 daemon starts, 18 with raindrop live) contains **exactly 2 raindrop send failures** — ~0.01% of 60s ticks. A vote-carry map to protect a provenance label at that rate is the guard whose complexity exceeds the bug. The error also biases toward `latched`, the honest direction.

**The real gap: `usage.ts` `if (!usage && tools.length === 0) continue` is load-bearing and had zero coverage.** Deleting it passed all 2383 tests. Real transcripts interleave a `tool_result` line between the `tool_use` lines of one message id; without the skip the turn splits and its tools are read apart — the exact defect the PR exists to prevent. My own A/B over 60 transcripts / 22M output tokens: **60 of 60 files change, 31,174 spurious turns, 2.18% of output tokens move phase.** Now pinned.

**Second gap: the `getProtocolContext(sessionId)?.role` join was untested** — every protocol test stubs `deps.protocolPhaseFor` wholesale, so replacing the join with `undefined` passed the suite. A rename of `role` upstream would have dropped protocol attribution fleet-wide, silently. Now pinned by a test that uses protocol name `build` with role `critic`, so only the role can produce the result.

**A test of mine was vacuous and the mutation check caught it.** The first latch-repair test passed with the repair deleted, because `nextLatch` runs again inside the turn loop. The guard is only load-bearing on the **empty-window early return** (`if (size === from) return done(from)`), where no turn runs. Retargeted at an idle read. See [[feedback_verify_new_assertions_can_fail]] — third time this has caught my own assertion.

**Also fixed:** dropped `forced !== undefined` (subsumed by `isUsagePhase`), un-exported `clonePhaseTotals`, corrected four factually wrong comments (a reference to `protocolPhaseForName`, which never existed; two claiming votes are scoped to the delivered window; one crediting `bankDelivered` with an invariant the adapter binding actually holds; one claiming a hoist closed a partial-build path a synchronous loop never had).

**Declined with reasoning:** `open.usage ??= usage` is correct by construction — the structure-line skip admits tools-without-usage lines and `??=` is what picks the envelope up later. Consolidating `turnLines`/`rich`/`turn` — three different test intents, and merging makes the shared fixture carry all three for every caller.

**RETRACTED — the sidechain hazard below is WRONG.** Verified 2026-09-28 by atlas: the JSON field isSidechain set to true appears in **0 main transcripts** and in 2406 subagent files. The round-5 ops reviewer scanned `subagents/*.jsonl` alongside main transcripts. Round 6's correctness reviewer independently found no sidechain lines either. PR 2 draining those files does NOT double-count, and `plan` is not ~40% subagent work. Kept for the lesson: two reviewers disagreed and the measurement settled it. Original claim:

~~**Sidechain spend is already counted.**~~ `turnsIn` folds every line carrying a `message`, including `isSidechain: true` subagent turns in the MAIN transcript. Measured over 400 transcripts (18.51B tokens): sidechain turns are 5.5% of spend and **91.7% of that lands in `plan`**; since `plan` is 12.7% of spend, roughly **40% of the `plan` bucket is delegated subagent work**. So draining `<sessionId>/subagents/agent-*.jsonl` in PR 2 **will double-count** unless it excludes what the main transcript already folds. The brief's "make double-counting impossible" requirement breaks exactly here. `drainUsage`'s `lastMessageId` dedupe does not help across files.

**Round 6** launched against `1080386`. Ops lens returned **"no concerns"**; correctness and test/mutation still out.

---

**ROUND 6 (2026-09-28, atlas).** Against `1080386`. Ops lens: **"no concerns"**. Correctness: 1 finding. Mutation: 67 run, 11 survived, 6 findings. Round resets. Fixed and amended to **`28bf5bc`**, signed, green: 2390 pass, tsc 56, 3 entry points.

**Egress-gate hole, fixed.** `raindrop-payload.ts` `safeExtra` short-circuited on `typeof v === 'number'` **before** the `EXTRA_PROPERTY_GATES` lookup, so a numeric `phase` rode onto the wire while the string `'bogus'` was correctly dropped. Probed directly: `phase: 42` shipped as a number. Now a gated key never takes the numeric path. The `test.each` at `raindrop-payload.test.ts:180` covered seven strings and no numbers.

**`report` loses 5–12% of its own bucket to the read boundary, one-directionally — ACCEPTED, documented.** A turn's envelope is booked on the first read that sees any line of it. A latched phase recovers because a late tool still moves the latch; `report` is momentary by construction so a late egress vote recovers nothing. Reviewer measured −12.4% on a real 60s write-timeline replay; atlas measured −5.3% on fixed 12-line chunks (conservation exact both times). **Why not fixed:** retro-attribution needs `lastTurnPhase`/`lastTurnUsage` on the cursor, but `phaseTotals` is cumulative and the baseline may already be delivered — moving tokens out of a delivered bucket emits a **negative delta**, breaking the invariant the fuzz runs verified, and repairing that reintroduces round 5's read-vs-delivery scoping problem. The `usage.ts` KNOWN LIMIT comment previously said "~8% of one phase" and implied symmetry; both wrong, now corrected.

**A vacuous test deleted, and it was not mine.** `raindrop.test.ts` `test.each(['constructor','toString','__proto__','valueOf','critic'])` had **zero mutation score** — against the shipped ternary, four cases assert `undefined === undefined` and a mutation returning `'review'` for every role did not fail it. It was written for a `Record` lookup that no longer exists. Folded the two prototype keys into the neighbouring test as concrete `toBeUndefined()` assertions, which a Record implementation genuinely fails (verified).

**Also pinned:** the `__` boundary in `REPORT_TOOL` (without it `noreply`, `auto_reply`, `bulk_reply` become chat egress); an id-less line following an id-bearing one (inheriting the open turn's id feeds it to the dedupe and discards its tokens); the no-user path through `usageBodies`.

**`usageBodies`'s two refusals are a redundant pair, not a coverage gap.** Removing either alone is an equivalent mutant — with `user === ''`, `buildTracked` refuses and the length guard catches it; with the length guard gone, the user guard catches it. Removing **both** banks a baseline for a window nothing sent, and that IS caught by the new test. Verified both ways.
