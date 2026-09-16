---
name: nova-banking-permission-backfill-gap
description: "Nova banking_permission split migrations forgot to backfill → 18,726 inconsistent rows (FA=true, view/transfers=false) silently deny view+transfers to pre-split members; owner can't self-repair via greyed UI. Fix = data backfill + frontend guard."
metadata: 
  node_type: memory
  type: project
  originSessionId: b5b00ff4-6bf9-49f3-97e1-458bfe8ec3f3
  modified: 2026-09-11T14:12:47.840Z
---

Investigated 2026-08-21 (spawned session "prism"), triggered by Kevin: nova owner (impersonating Don Craven) can't grant banking permissions to team members; greyed checkboxes.

**Root cause (definitive, from migration lineage) — the "break" PRs:**
- `20250711212444` created `banking_permission` with a SINGLE flag `can_manage_bank_accounts` (the whole banking permission). ~5 months of grants accumulate.
- `20251222113533` (**PR #6152**, commit a448de8ad4, 2025-12-22) renamed it → `can_manage_financial_accounts` AND added `can_view_financial_accounts NOT NULL DEFAULT false` — **no backfill**. PRIMARY break (every pre-existing banking member instantly view-inconsistent).
- `20251223023721` (**PR #6159**, commit 634092d2c1, 2025-12-23) added `can_approve_transfers NOT NULL DEFAULT false` (renamed → `can_manage_transfers` by `20260409000001`) — **no backfill**. (PR #6150 = frontend component, #6168 = Meridian cascade — related but NOT the data break.)
- Result: every pre-split banking member now has `canManageFinancialAccounts=true, canViewFinancialAccounts=false, canManageTransfers=false`. **18,726 inconsistent rows in prod** (verified via `just console -p` prisma, 2026-08-21). Don's Meridian permission_set `bf406f76-3251-452b-81ba-05849e9c5ceb` is one; his recipient one `30153c13…` is consistent (all-true).

**Why it bites:** authz gates on the GRANULAR flags — `financialAccount/list.ts:28` needs `canViewFinancialAccounts`; `transfer/create:215`, `paymentTransfer/create:231`, `transfer/transition:76`, `bankTransfer/create.ts:88`, `moneyMarketFundOrder/create.ts:86` need `['canManageTransfers']`. `hasPermissions` (`graph/src/data/entity/financialAccount.ts:151`) ORs only the passed flags — NO superset expansion. So superset-holders with defaulted-false children are DENIED. Owner can't self-repair: `BankingPermissions.tsx:37-40` greys children when parent checked; cascade to set children true only fires on click (`lines 65-69`), never on load. `mapMembers.ts:55-57`/`getDefaultValues` read raw DB → greyed checkbox is a FAITHFUL read (not a display bug).

**Restoration, not escalation:** `can_manage_bank_accounts` was full banking pre-split; label "Create and manage bank accounts, transfers, and controls" present since #6150 (`3941bcb7bc`). Backfill = the step #6150/#6159 omitted. Write path now enforces consistency via `BankingPermissionSchema.superRefine` (3 rules: FA⇒view, FA⇒transfers, transfers⇒view) + `upsertBankingPermission.parse()`, so it's a one-time repair.

**Fix (survived 3-round adversarial review; NOT yet implemented):**
1. Idempotent data backfill: `UPDATE banking_permission SET can_view_financial_accounts=true WHERE (can_manage_financial_accounts OR can_manage_transfers) AND NOT can_view_financial_accounts;` then `SET can_manage_transfers=true WHERE can_manage_financial_accounts AND NOT can_manage_transfers;`
2. Frontend guard: `getDefaultValues` (`BankingPermissions.tsx:88-92`) derive implied-true on load.

**Open decision (Kevin):** blast radius — (a) full 18,726 restore, (b) scope to orgs with active financial accounts [recommended], (c) stage view-first then transfers. Plus grant-vs-strip (restore "move money" vs owner-only). Implement in worktree, staging→prod. WITHDREW an earlier proposed fix (making transfer authz accept `canManageFinancialAccounts`) — that's a table-wide authz change, not a data repair.

**CORRECTED IMPACT (2026-08-25 prod):** total banking_permission=43,225; inconsistent=18,722; inconsistent-as-active-member's-current-perm=17,849 (so NOT mostly dead history — only ~873 stale). BUT actionable = members in a **banking-active org** (org has entity_financial_account): **~14 total** — MERIDIAN 17,826 affected but only **3** banking-active; RECIPIENT **12** affected, **11** banking-active (= teddy's exact WALLET-40 cohort, 11 members/6 wallets); SENDER 11 affected, **0** banking-active. So "18k" is real as rows but user-impacting set is ~14, concentrated in recipient orgs. WALLET-40 fingerprint confirmed: recipient missing_view=1/missing_move_money=12 (view restored, transfers not); Meridian missing BOTH (untouched). Meridian members carry can_manage_financial_accounts=true broadly but 17,823/17,826 have NO financial account → permission inert, only symptom = greyed un-editable UI (Don's case = N-208's literal "allow admins to edit" ask, not a money denial). Possible SEPARATE provisioning hole: why Meridian members get banking flags at all (untraced).

**MERGED (both by Kevin/kwliang1, 2026-08-26 00:15) — 2 PRs, passed pre-push review gate (2 clean rounds):**
- **FE #9703** (branch `kevinliang/n-208`): `BankingPermissions.tsx` `getDefaultValues` derives manage⇒transfers⇒view on load so a checked parent never renders greyed-unchecked children. + unit test. MERGED to main.
- **Backfill #9704** (branch `kevinliang/n-208-backfill`): engbot action `BackfillBankingPermissionHierarchy` (dry-run default), repairs ALL inconsistent rows (Kevin chose full incl. Meridian) via `upsertBankingPermission` (schema-revalidated, idempotent, monotonic). Scope table in PR body. Precedent = #7504. MERGED — but **merging only deploys the action; UNKNOWN whether ever RUN with `{execute:true}` in prod.** If NOT run, the 11 recipient members (incl. Kristin) are STILL backend-denied.

**MECHANISM — "why does Donald still can't manage Kristin's perms after FE fix live" (Kevin q 2026-08-26, resurrected cedar answered 2026-09-11):** (1) #9703 fixed only the CHECKED STATE, NOT the greying — `isDisabled` logic UNCHANGED (`BankingPermissions.tsx`: view disabled when manage-FA||transfers checked; transfers disabled when manage-FA checked). So child switches render checked-but-greyed under a checked parent = intended hierarchy, can't toggle independently. PARENT switch (`canManageFinancialAccounts`) is ALWAYS editable (no isDisabled). (2) Kevin tested ~18min post-merge → FE fix likely not deployed yet (Buildkite commit-order deploys). (3) DATA: Kristin's row still inconsistent until #9704 runs OR Donald opens+saves her editor (FE fix now writes implied-true consistent row = per-member manual repair). Awaiting Kevin: is thread still live / was #9704 executed.

GOTCHAS hit: nova-authz/nova-engbot unbuilt in worktree (`pnpm turbo build --filter=@angellist/nova-authz` etc.); worktree-init cut FE branch off STALE main + carried a stray commit from the other checkout's branch — had to `git rebase --gpg-sign --onto origin/main <stray> kevinliang/n-208`. `just console -p` needs `al` (not on this box). N-208 reassigned back to Kevin/us (was misassigned to Harshaneel). Findings artifact (org-wide): https://claude.ai/code/artifact/d7e84a34-0526-4d59-9d1a-ea48973fab61

**This is N-208** ("Allow admins to edit member banking permissions", created Jack Plank 2026-08-21, **assignee Harshaneel Gokhale**, branch `kevinliang/n-208`, In Progress — NOT me; I did not start impl). Same bug confirmed independently by teddy.ruby note: Kristin Shoaf (member of Donald A Craven Jr recipient org) denied withdrawal; migration residue; prior partial fix = **WALLET-40** (restored view+manage, not transfers). teddy scoped live impact to 11 non-owner members / 6 wallets on one Capital Factory distribution; our audit = 18,726 table-wide. Mechanism reverified: authz is flag-gated with NO admin/role bypass (`financialAccount/list.ts:28` view; `transfer/create` authz `['canManageTransfers']`) — denies owner too. Org-created dates align (Meridian dogScMIoCUbt org 2025-07-29 / grant 2025-07-30 pre-split → broken; recipient doa3XO9P_AWt healed via post-split re-save).

**Findings artifact:** https://claude.ai/code/artifact/d7e84a34-0526-4d59-9d1a-ea48973fab61 (Kevin to set org-wide via Share menu).

Note: Meridian blade (`MeridianBlade/index.tsx:89`) additionally passes `cascadeFromCanManageFinancialAccounts` (#6168, 2025-12-23) which hard-greys children always — separate/secondary to this data bug. nova banking_permission is NOT replicated to Snowflake (only permission_set/meridian_permission/position_permission are).
