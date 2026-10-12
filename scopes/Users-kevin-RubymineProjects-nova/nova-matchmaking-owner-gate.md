---
name: nova-matchmaking-owner-gate
description: "#9830 (BANK-1941) owner gate: commitRowCore is the single choke point, headless ports impossible on all 4 paths; async commitBatch can never port a NEW entity for ANY csv. PLUS Kevin's 2026-09-12 rule — create by email AND id (match-only reversed), BANK-1950 is nova-only via the wedge BULK route, and the measured 7-11.5% secondary-email rate that justifies it."
metadata: 
  node_type: memory
  type: project
  originSessionId: 01e897ec-d7f1-4847-a00b-fe5314ec5717
  modified: 2026-09-10T15:01:15.331Z
---

Answered for Kevin 2026-09-10: "I deployed the owner-email PR but have a pre-existing matchmaking CSV with no owner column — will it port headless entities/bank accounts?" Verified against `origin/main` @ `aedc43e527`. **No headless entities possible.** #9830 (BANK-1941) merged 2026-09-09.

**`commitRowCore` is the single choke point.** Exactly 4 callers, all gated: the per-row `commitRow` mutation, `bulkCommitRowsCore`, the Temporal `commitMatchmakingChunk` activity, and `forceSyncRow`. Grep `commitRowCore|canResolveEntityOwner` to re-verify — if a 5th caller ever appears it bypasses nothing only if it routes through core.

Two independent guards:
1. **Pre-commit**: `canResolveEntityOwner` (`commitRow.ts:187`) runs BEFORE the idempotency key binds → outcome `NO_OWNER_ACCOUNT`, nothing written, and **deliberately does not bind the key** so the row stays cleanly committable once the owner exists (`commitRow.ts:183-186`). Non-stranding by design.
2. **In-transaction**: `resolveOwnerAccount` (`executePort.ts:87-88`) hard-errors `'Port would create a headless entity'`. Comment at `:39-42` — by the time a new entity is created the gate already guaranteed an owner, so every miss here is a gate/port race, never a silent headless port.

**THE GAP worth remembering — the async "Commit batch" button cannot port a NEW entity for ANY csv, even one with a full owner column.** `commitMatchmakingChunk.ts:52-56` passes `ownerEmail: undefined, ownerUserId: undefined` unconditionally because the Temporal payload is deliberately PII-free (rowIds/rowNumbers only). Its own comment: *"only wallet-ensure commits succeed here until this path re-fetches the CSV by reference."* So every new-entity row on that path settles `NO_OWNER_ACCOUNT`. Only per-row commit + bulk commit create entities — they carry the client's CSV parse in the mutation input. Offered to file it; Kevin hadn't answered yet.

Non-obvious details:
- **Bank accounts DO move on ownerless rows — onto entities nova already holds.** `upsertWalletAndReferences` runs on BOTH branches of `executePort` (`:191-198`), and the gate passes *unconditionally* when `novaHoldsEntity` is true (`ownerResolution.ts:53-55`). Not headless (the entity already has its own access, and the code explicitly avoids adding an owner — "never a second org and never a silently-added owner"), but it is a real write from an ownerless CSV.
- **Owner is only ever read from the ARCHIVED csv**, live-reparsed client-side (`useCsvRows` → `ENTITY_MIGRATION_INGEST_FILE` → `parseIngestRows`). There is no way to supply owners at commit time through the UI. Fixing a bad batch = **re-stage with an `owner_email` column**, not re-click commit.
- Gate ladder (`ownerResolution.ts`): entity already held → pass; `ownerUserId` → account by angellistId (soft-deleted refuses outright); id missed → email may decide ONLY if unclaimed or on an id-less account (an email on a *different* angellistId is positive proof of a wrong-person row); email-only → must already be an account. Email-keyed shells are NEVER created (a secondary venture email strands the grant). `parseOwnerUserId` rejects `0` specifically — blank-cell coercion artifact.
- UI pre-warns before the click: dialog lists exactly which rows will refuse (`BulkActionDialog.tsx:357`), refused rows read "owner not found — refused" (`:80`), and an unreadable archived CSV **blocks** commit outright rather than spamming refusals (`:111-114`).

See [[nova-entity-matchmaking-scorer]] (the older `port_final.js` ops-script path, which skipped rather than gated), [[nova-bank-1943-commit-idempotency]] (#9871 rewrites `resolveKey` in this same file), [[nova-lp-porting-review-tab]].

## 2026-09-12 — Kevin DECIDED the owner rule, reversed it the same day

Final: **create by email AND id, never by email alone.** He first ruled match-only ("only match existing Accounts where `account.angellistId` is populated"), I relayed that to the implementing session, then he reversed it within the hour.

Match-only fails for a plainer reason than the duplicate-entity path: a row whose owner will not resolve returns `NO_OWNER_ACCOUNT` and **never ports at all**, so the rule would stall precisely the rows this tool exists for — LPs nova has never seen. Creating is safe because an id-keyed account reconciles at first login (`accountFromAngellist` checks `angellistId` before email, `graph/src/lib/auth/account.ts:69-85`); an email-keyed one would strand, which is why that half stays a refusal.

Note his stated intent did **not** match shipped code, which is what surfaced the question: `executePort.ts:67-84` already called `findOrCreateByAngellistId`, minting an id-keyed shell with the email as handle/legalName/displayName. `resolveKey` excludes the owner from the commit key but `contentHashFor` includes it — so correcting an owner email and retrying gives a permanent `IDEMPOTENCY_CONFLICT` (same key, different hash); correcting the *pick* works.

**BANK-1950 is nova-only — no venture PR.** The ticket specs a new Prophet route; that is stale. Kevin ruled to reuse the existing wedge rail, and the endpoint already calls the exact method: `GET /wedge_products/api/v1/users/email/:email` (venture `config/routes.rb:397`) → `UsersController#find_by_email` → `FetchService.find_by_email!` → `User.find_by_any_email`. **Use the BULK route instead** (`routes.rb:399` `users/emails` → `find_emails`): `WedgeProducts::BaseController:16` is `rescue_from StandardError` rendering 400 + a Sentry event for everything including `RecordNotFound`, so on the singular route an ordinary miss is wire-identical to venture being down and pages Sentry every time. The bulk route answers a miss with `users: []` in a 200, takes a comma-separated batch (one call per commit, not per row), and returns `primary_email`/`secondary_emails`/`all_emails`.

BANK-1950's real weight is **not** secondary-email cleanup: before it, an email-only row carries no venture id, so `findOrCreateByAngellistId` has nothing to key on and cannot create even when you want it to. It is the precondition for seating owners on email-only rows.

**Measured on venture prod 2026-09-12** (read-only console; `SecondaryEmail` distinct on `user_id`): 365,056 / 16,061,083 = **2.27%** of all users carry a secondary email, but **7.15%** of 365-day-actives and **11.51%** of 90-day-actives do. Anyone named as a CSV owner is an active user by construction, so the relevant miss rate is the 7–11.5% band. At 2% the BANK-1941 refusal gate would have sufficed. `SecondaryEmail.map_email_to_user` is `find_by(email:).try(:user)` with **no `email_type` filter** (`app/models/secondary_email.rb:58-60`), so all 437,703 rows resolve including the 10,661 typed `backup`.

**Hazard the decision leaves open:** nothing validates a CSV `owner_user_id` against venture. A typo'd id plus an email nova has not seen mints a shell keyed to whatever number was typed, and the venture user who really holds that id inherits super-admin + full banking at their next login. The guard at `executePort.ts:80-83` only fires when an account already exists for that email. The implementing session closes this for rows carrying BOTH id and email (it refuses when venture's answer disagrees with the asserted id); a row with an id and no email still has nothing to check against.

**Filed 2026-09-13: BANK-2078** — the row keeps no record of who was named as owner. Owner email and user id are commit arguments read from the CSV at commit time and dropped; no matchmaking table has an owner column. So nobody can audit whether a port seated the person the file named, and "how many rows name an owner nova has never seen?" is unanswerable from nova. The ticket deliberately does **not** store the email (that would breach the locked no-PII decision); it proposes `owner_account_id`, `owner_user_id`, and an `owner_resolution` enum.

See [[nova-directory-email-banking-door]] — the port's ladder is the narrower of two gates onto the same banking permissions, and it does not rescue an unseated owner.

## 2026-09-25 — BANK-1948 is still open, but the issue text is stale on both of its stated harms

Kevin asked "BANK-1948 is done, no?" Verified against `origin/main`: **not done.** Linear `Todo`, no `kevinliang/bank-1948` branch, no PR, and `git log --since=2026-09-11 -S ownerEmail` over `forceSyncRow.ts` / `types.ts` / the force mutation returns nothing. `ForceSyncRowArgs` (`types.ts:111-118`) still has no `ownerEmail`; `forceSyncRow.ts:105` still calls `commitRowCore({ rowId, idempotencyKey })`. Its three siblings all closed in that window (BANK-1941, BANK-1950 #10269, BANK-1936 #10292), which is what makes it *look* done. `forceSyncRow.ts` did change 2026-09-16 — that was #9871 (BANK-1943 keys), not owner threading.

**Both harms the ticket leads with are already closed:**
- *Headless entity* — the create branch refuses: `canResolveEntityOwner` returns `okAsync(false)` with no email/userId (`ownerResolution.ts:177`) → `NO_OWNER_ACCOUNT` → `NOT_APPLICABLE`. Pinned by `forceSyncRow.test.ts:91`.
- *The "callout never fires" masking* — `fsm/entityMatchmaking.ts:343-345` stamps an **ownerless** content hash when `ownerHoldsAccess` is false ("Bind what the port applied, not what the caller asserted: a dedup port grants no owner"). A later commit carrying the email hashes differently, so `judgeAgainstPorted` (`commitRow.ts:174`) returns IDEMPOTENCY_CONFLICT. It does surface now.

**What actually persists: a force onto an entity nova already HOLDS ports it with no owner grant.** The chain — `runEligible` (`commitRow.ts:413`) → `novaHoldsEntity` true → `heldEntityOwner` → `resolveOwnerThroughVenture` with an all-undefined owner returns `{kind:'resolved', resolvedBy:'noEmail'}` (`ownerResolution.ts:81-82`) — **resolved, not unresolvable** — so it proceeds to `runCommitAttempt` with an empty owner. The owner gate only ever guarded entity *creation*. Note this is the force-sync face of the ownerless-dedup write already recorded above.

**No path repairs it.** The dedup branch only probes (`executePort.ts:25-26`, `:262-264` — "a dedup wallet-ensure grants nobody either way"), and commit is one-shot, so a re-commit hits `handleAlreadyCommitted` and reports without repairing. The only writers of that grant reachable afterwards:
1. `orgMember/editMember.ts:62` / `invite/inviteMember.ts:66` — both `throwUnless.accountIsOrganizationAdmin`. **The manual fix**, per affected row, on someone else's org.
2. `distribution/payments/autoJoinOrgIfEmailMatch.ts:128` — auto-grants full banking, but only on a distribution payment + DirectoryPerson email match. Incidental. See [[nova-directory-email-banking-door]].
3. `routers/internal/sync/investAccount.ts` `bankingPermissionFromMemberSchema` — venture sync, but **set-once**: returns `undefined` when the RECIPIENT org already holds any banking permission, which a held entity's org almost always does.

So BANK-1948 should be re-scoped (its premise is stale) and should carry a **detection query** — today there is no way to list rows ported with `ownerHoldsAccess: false` short of re-committing each one and reading the conflict.

### Measured on nova prod 2026-09-25 — the force-sync gap has never fired

Kevin ran the detection in his `NOVA-GRAPH:PRODUCTION` REPL (read-only; recompute `sha256(rowId + matchedIpseityEntityId)` and compare to `fsm_execution.context.portedContentHash` over every COMMITTED execution on the `entityMatchmaking/row` workflow). Of **115** COMMITTED executions:

| bucket | n |
|---|---|
| `ungranted_forced` | **0** |
| `ungranted_normal` | 9 |
| `granted` | 46 |
| `unknown_pre_hash` | 60 |
| `no_row` | 0 |

**BANK-1948 is latent, not live** — no force sync has ever ported a row in prod. The 9 ungranted ports are all *normal* commits, which confirms the gap is the dedup path itself (grants nobody regardless of caller), not force sync. They span 3 uploads (`26d6adb6` rows 7/13/15, `f168faf0` rows 13/45/55/61/23, `dbfe0927` row 18) but only **7 distinct entities**: `dc740f20` and `e63abe42` were each ported twice, once per upload, *both* ungranted — so those entities predate matchmaking rather than having been created by an earlier granted port.

**The detection cannot distinguish two cases**, and this limits any remediation: the ownerless hash is stamped both when (a) the CSV named an owner who did not get the grant, and (b) the CSV named nobody. Telling them apart needs the archived CSV for those uploads, because [[BANK-2078]] (owner column not stored) is still Backlog. `unknown_pre_hash: 60` — over half of all ports, committed before #9871 added `portedContentHash` — is unclassifiable by this method entirely.

Paste-mode gotchas worth reusing: the REPL exposes `prisma` (`graph/scripts/repl/prisma.ts:20`) and has auto-await, so a single `await (async () => {…})()` expression pastes cleanly. And **`al` is not on this session's PATH** — it is at `/Users/kevin/bin/al`; the `al console push <src> <dst> -a nova -p` arg order itself is correct per `--help`. `just console -p` is the wrong thing to ask an agent to run: `justfile:365-368` deletes the existing prod console before creating, and `-a nova-graph` is RBAC-forbidden here.

**2026-09-28 follow-up — all 9 are real.** Kevin re-read the archived CSVs through `getIngestFileBytes` + the stager's own `parseIngestRows` (so row indexing matches `prepareBatch.ts:125`'s `rowNumber: index + 1`): every one of the 9 rows carries an `owner_email`, and every row in all three files does (18/18, 62/62, 154/154). None have `owner_user_id`. So the ambiguity noted above resolves the bad way — these are named owners the dedup path silently dropped, not blank cells. Remaining check before remediation: the hash records port-*time* state, so re-probe `holdsBankingGrantOnEntity({canManageTransfers,canManageFinancialAccounts})` against today's DB — venture sync or `autoJoinOrgIfEmailMatch` may have healed some.

Recipe worth keeping: the prod REPL can reach the archived CSV — `await import('services/entityMatchmaking/getIngestFileBytes')` and `@angellist/nova-core/entityMatchmaking/ingest`, both resolvable by dynamic import under tsx despite the frozen REPL context (which exposes only `prisma`, `EngBot`, `documentServiceClient`, `libDataRoom`, `getTemporalClient`). `requestingUser` must be a real admin email — DocumentService audits the read. Print booleans, never cells: the files hold TINs, names and emails.
