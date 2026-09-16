---
name: nova-matchmaking-local-e2e
description: "Entity-matchmaking scoring e2e — MATCHMAKING_SCORING_ENABLED gate (OFF in prod too), ipseity-app-1 container, demo seeding recipe, prod triage sequence"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6c337ba4-0475-45ef-b6cb-7727fa332a3e
  modified: 2026-09-08T20:53:25.209Z
---

Rows stuck STAGED / upload PENDING after staging = scoring never ran. Two usual causes (both hit 2026-08-28):

1. **`MATCHMAKING_SCORING_ENABLED=true` must be in `.devcontainer/.env`** (checked as the literal string 'true', `graph/src/lib/config.ts:55`). It's the deliberate PII-into-Temporal gate — `stage()` logs a warn and leaves rows STAGED when off. `just` re-reads the dotenv per invocation, so restarting only `graph` + `graph-worker` via process-compose (`POST localhost:7599/process/restart/<name>`) picks it up — no full-stack restart.
2. **`ipseity-app-1` docker container tends to be exited.** `docker start ipseity-app-1` (deps `ipseity-pg-db`, `ipseity-temporal` usually stay up). Nova→ipseity is Prophet over local NATS (OrbStack forwards 4222); treasury container `treasury` (7020→3000) usually stays up.

Verify scoring ran: `temporal workflow list --address 127.0.0.1:7847 --namespace nova --query "WorkflowType='scoreMatchmakingBatch'"` (namespace is `nova`, NOT default; worktree cedar port 7847, UI 7851).

Demo/repair scripts (untracked, in worktree cedar `graph/scripts/`): `restageStuckBatch.ts <uploadId> <email>` re-drives a stuck batch from its archived DocumentService file (hash replay converges); `stageDemoBatch.ts <csv> <name> <email>` stages through the real reserve→archive→stage path. Run with `set -a && source ../.devcontainer/.env && set +a && npx tsx …`.

Seeding: use `graph/scripts/seedMatchmakingLocalDemo.ts` (worktree cedar, untracked) — idempotent, seeds ipseity people+companies, KYC-verifies, links treasury INVESTMENT wallets, writes the progression CSV. Gotchas baked into it:
- KYC-verify sequence is load-bearing: `s.update!(identity_state_manually_verified: true, watchlist_state_manually_verified: true)` FIRST, then `s.identity_state_event = :manually_approved` (+watchlist) + `save!` — the transition guards require the manual flags; `fire_*_event` alone silently no-ops.
- `entity.destroy!` does NOT cascade identity_data rows in dev — orphans still match name lookups; dedup via `IdentityData::Person.where(...).filter_map(&:entity).first`.
- Person SSN is blind-indexed with no exposed `generate_ssn_bidx`; dedup by name (citext), not TIN.
- Company `verified?` additionally needs KYB (signatories/control persons/US incorporation) — demo companies stay unverified (they demo the "not KYC-verified" review reason).
- Duplicate entities per TIN ⇒ "TIN matches more than one ipseity entity" CONFLICT — wipe+reseed if you get generations of dupes.
- Full pass reason: "TIN + type + KYC + wallet pass; name is a strong match" → AUTO_MATCH.
- Rows staged while the gate was OFF have NO FSM executions — reject returns NOT_FOUND; re-drive (restageStuckBatch) first, then reject.
- Scripts must live in graph/scripts/ (tsx treats /tmp as CJS → top-level-await errors).

**Hollow-validation traps (both bit hard 2026-08-28):**
- `npx biome` in graph resolves an unrelated broken npm package (exits 0, prints nothing) — ALWAYS `pnpm exec biome` (resolves @biomejs 2.x via workspace). AGENTS.md warns about this; the warning is real.
- graph `tsc --noEmit` can OOM (heap 4GB) and die with exit 1 and ZERO "error TS" diagnostics — a `grep "error TS"` validation then reads as clean. Run with `NODE_OPTIONS=--max-old-space-size=8192` and check the exit code + that diagnostics/clean-exit actually occurred, never grep alone.

Nova worktree DB creds: `nova` / password in `.devcontainer/.env` `POSTGRES_PASSWORD` (port 8126, db nova_nova_cedar); tables are singular (`entity_matchmaking_upload`/`_row`). Already-scored rows never re-score (scorer skips non-STAGED); to demo a new outcome, stage a fresh (content-differing) batch. See [[nova-entity-matchmaking-scorer]].

**PROD triage (2026-09-01, upload `dbfe0927-e542-40f6-8632-6e4d07f3d872`):** the same gate is OFF in prod — `MATCHMAKING_SCORING_ENABLED` is unset on the prod graph + nova-temporal pods, so `scoreMatchmakingBatch` completes green with `{scored: 0, deferred: 0}` and reads as a silent failure. Diagnose from Datadog with `env:prod @uploadId:<id>` — the UUID is an ATTRIBUTE, so bare free-text search on it returns only nginx/nova-app referrer noise. Three-line signature: `Reserved matchmaking ingest document` (nova-graph) → `Failed to prepare matchmaking batch for scoring / Ingest document is still finalizing` (nova-temporal) → `Matchmaking scoring gated off — rows staged, not scored until enabled` + `stagedRowCount`.

**The still-finalizing error is a RED HERRING, not the cause.** It's attempt 1 of `ingestActivities` (2s initial / 30 attempts, `activityProxy.ts`) losing the PUT→S3→finalize race; attempt 2 succeeded 4s later. Don't retry the workflow on it — flip the flag, then re-run.

**Comment-vs-code inversion at `prepareBatch.ts:119-121`:** the comment claims the gated path does "create + begin rows so a re-run once enabled repairs and scores them", but `return okAsync(emptyResult())` fires BEFORE `beginPendingExecutions` — rows are created, never begun. Recovery is still intact (the re-run begins anything un-begun), so it's a wrong comment, not wrong behavior — same inversion class the reviewers kept catching on the [[nova-lp-porting-review-tab]] stack.

**Repairing a gated-off batch: the UI blocks you (found 2026-09-01).** `isBatchStalled` = `PENDING && rowCount === 0` (`app/.../EntityMigrationTab/helpers.ts:132-134`). A batch whose rows DID land but never scored (the gated-off case) is PENDING with rows, so `duplicateBlocked` is true and the Stage button is disabled — "has identical content, so staging is disabled". The re-stage repair path was written only for an ingest that died before any row landed. **The gate is CLIENT-side only**; server `stage()` has no such check (`findOrCreateUpload` converges on the existing upload by `ingestDocumentId` and re-kicks). Two ways through: re-run/reset the `scoreMatchmakingBatch:<uploadId>` workflow directly (prior run is CLOSED so a new run starts — `startWorkflowIdempotently` only swallows the kick while a run is OPEN), or call `adminEntityMatchmakingStage` with the existing documentId. **NEVER edit the CSV to dodge the hash** — different content = different document = a NEW batch, orphaning the original 154 rows.

Shipped as PR #9833 (`kevinliang/enable-matchmaking-scoring-prod`): flag on in `prod-us-west-2-zeus` + `staging-us-west-2-hermes` only, both stale comments deleted, per-chunk `Scored matchmaking chunk` log added. See [[nova-configtool-staging-zeus-is-prod-cluster]] for why the third stack was excluded.

**BANK-1923 pick/unselect e2e checklist** lives in Arti `nova-bank-1923-entity-migration-e2e` (11 curated manual cases, each mapped to its backing coded test: selectCandidate.test / deselectCandidate.test / RowBlade.test / helpers.test). Only "names populate" (DocumentService) is e2e-only. Blank Entity-name column = expired doc-service AWS SSO, see [[nova-entity-migration-names-docservice-sso]].

**Gate-down signature (2026-09-08):** a candidate panel showing "Identity fetch failed / Couldn't load this candidate" (ipseity read) + "Treasury read failed" (wallet), and a pick toast "Couldn't select the candidate — the live KYC and wallet check could not be reached" (selectCandidate ERRORED), while `docker ps` shows ipseity-app-1/treasury/nats all Up and NATS 4222 open = graph's Prophet/NATS client went **stale**, not a dead container. Fix: restart BOTH `graph` (handles the pick mutation + identity query) and `graph-worker` (handles scoring) via `POST localhost:<pc-port>/process/restart/<name>`. process-compose log REST endpoint returned empty/404 in the pixel worktree — couldn't pull graph's error that way.

**Pickable-CONFLICT seed (PR #9952):** the demo seed had NO runnable Conflict for the pick flow (only a 0-candidate row + a correctly-unpickable type-mismatch). Added a shared-SSN person pair (Ada Lovelace verified+wallet / Augusta Byron unverified) → a TIN row matches both → ">1 TIN hit" CONFLICT with 2 candidates; pick Ada → AUTO_MATCH. **Seed gotcha:** the script's output map was keyed by SSN, so a shared-SSN pair collapses to one entry and mis-targets wallet linking — key by NAME instead. CSV is `entity-migration-e2e.csv` (13 rows; Ada = row 13).

**Rollback semantics (correct these if you quote them):** the gate is read ONCE, in prepare — a batch past that point scores to COMPLETION, every remaining chunk; restarting pods does not halt it (Temporal retries the activity on the new pod). Killing a run = terminate `scoreMatchmakingBatch:<uploadId>`. And `deferred` mostly self-heals on re-stage EXCEPT an `ERRORED` FSM execution, which never recovers (`scoreRows.ts:132-133`; `isHealthyExecution` excludes ERRORED) — deferral surviving two re-stages means investigate `stuckRowIds`, not re-stage again.
