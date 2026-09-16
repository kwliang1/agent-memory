---
name: nova-matchmaking-upload-status-stale
description: "entity_matchmaking_upload.status sticks on SCORING forever after scoring finishes — the workflow stamps it on entry and never clears it. Harmless in-product (reads recompute), but it makes the column useless for detecting a genuinely stalled scoring run."
metadata:
  node_type: memory
  type: project
  originSessionId: 0d5b8057-25e5-4594-8e8e-fd60088856e4
  modified: 2026-09-14
---

Found 2026-09-13 while assessing prod batches; Kevin confirmed it as a bug and handed the fix to another session on 2026-09-14 (in progress, no ticket filed as of this writing).

**The bug.** `prepareBatch.ts:126` stamps `status = SCORING` when scoring starts. The `scoreMatchmakingBatch` Temporal workflow then walks its chunks and returns **without ever writing the status again**. The only thing that corrects the column is `refreshUploadStatusForRows` (`graph/src/services/entityMatchmaking/getBatch.ts:178`), and every caller is a reviewer *action*: commitRow, commitBatch, selectCandidate, deselectCandidate, forceSyncRow, rejectRows. So a batch that finishes scoring and is then left alone sits at SCORING indefinitely, and self-corrects the instant anyone touches a row.

Observed in prod 2026-09-13: two batches scored ~46h earlier, every row scored, zero STAGED rows, stored status still SCORING. `rollupStatus` (`rollup.ts`) returns SCORING **only** when a row is STAGED, so the derived value was REVIEW the whole time.

**Why it doesn't break the product.** Both read paths recompute the rollup from row counts — `getBatch.ts:43` and `summaryStatus:55` — and consult the stored value only when the batch has zero rows. The UI has always been right.

**Why it still matters.** Anything reading the table directly — Metabase, the Flowdash marts, ops scripts, alerts — sees SCORING forever. The sharper cost: **you cannot use this column to detect a genuinely stuck scoring run**, because a healthy finished batch is byte-identical to one whose workflow died mid-way. That is exactly the monitor you would want given BANK-1901's serial chunking, and it cannot be built on this column today. If you query the DB directly for batch state, derive the rollup yourself.

**The fix and its three traps** (worked out with Kevin, handed off):
1. Add a terminal activity calling the existing `refreshUploadStatus({ uploadId })` (`getBatch.ts:154`), fired only on successful completion — a workflow that dies mid-scoring *should* leave SCORING standing.
2. `workflow.ts` early-returns at `scoreableRowNumbers.length === 0` before any chunking. **Re-staging an already-scored batch lands there**, because `prepareBatch` filters to STAGED rows. That path needs the refresh too or you have fixed only the common case.
3. The activity proxy is `maximumAttempts: 3`, so a failing refresh would fail the whole workflow — turning a successful scoring run into a failed one over bookkeeping. The reviewer paths deliberately treat this as best-effort (`getBatch.ts:172-177`): swallow and log inside the activity.
4. Deferred rows need no special handling — they stay STAGED, so the rollup returns SCORING correctly on its own. Do not add a guard.

Aside for whoever touches it: `activities/index.ts` uses named re-exports, which nova's AGENTS.md forbids for barrels (`export *` only). Pre-existing; match the neighbours rather than refactoring, but expect a reviewer to flag it.

See [[nova-matchmaking-retro-artifact]], [[lp-porting-fund5-fund6-csv-defects]].
