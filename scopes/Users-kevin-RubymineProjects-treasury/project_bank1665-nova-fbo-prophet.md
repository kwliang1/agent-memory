---
name: project_bank1665-nova-fbo-prophet
description: "BANK-1665/NOVA-3466 PR1 — FBO account creation over Prophet; recovered, green, awaiting IVC confirmation"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2dfc225a-19da-456a-be1c-06d79f8a684d
  modified: 2026-07-22T22:54:28.535Z
---

PR 1 of BANK-1665 / NOVA-3466 ("onboardVehicleAccounts — FBO onboarding over Prophet"). Scope: **support FBO account creation in Prophet** (PR2 = nova engbot rewrite, separate, out of scope).

**Location & durability:** work lives in worktree `treasury-prism` on branch `kevinliang/nova-3466-fbo-account-creation-prophet`, based off fresher `origin/main` (627ea24b). Committed + SSH-signed at commit (amended; latest `13d212f48`). **Two prior sessions (atlas, prism) lost this work by leaving it UNCOMMITTED in a torn-down worktree — always commit immediately for durability.** The `%G?`=N local-verify artifact is NOT unsigned; the `gpgsig` SSH header is present (1Password key) — GitHub verifies fine.

**What the diff does (7 files, ~243 insertions):**
- `treasury_prophet_api` `Create::Input`: 3 nilable consts `owner_type`/`beneficiary_name`/`fund_lead_entity_id` (gem `OwnerType` enum already had `Fbo`). Additive, NO gem release.
- `CreateService.create!`: FBO branch builds CustomerAccount as FBO + `build_fbo_identity`, skips `OwnerTypeService`; existing `perform_post_creation_setup!` opens sub-account inline. No IVC. Default nil owner_type → non-FBO path byte-identical (load-bearing; only caller is the Prophet handler).
- Service guard: FBO requires beneficiary_name always; requires fund_lead_entity_id only for non-NOVA sources w/ a program name (raises ArgumentError → InvalidRequestError).

**Kevin decisions (2026-07-21):**
- fund_lead_entity_id is a Venture concept — do NOT require it for NOVA; skip guard when `source == NOVA` (`CustomerAccount::NOVA = 'nova'`).
- NOVA FBOs must **never** land on GHB Omnibus. Fix applied in `resolve_fbo_program!` (`sub_account_requests/info_service.rb`): honor resolved program when `fund_lead present OR source == NOVA`; AngelList omnibus fallback untouched.

**Round-1 review (5 reviewers) fixes applied:** idempotency `find_by` scoped to FBO rows for FBO requests (FBO exempt from entity+purpose uniqueness → could return a non-FBO acct); comment discipline; spec nits; added NOVA specs. Verification concern retracted (auto-verified is standard for ALL non_standalone FBOs, not NOVA-specific).

**IVC RESOLVED (2026-07-21): Kevin confirmed NOVA FBOs are STANDALONE — no IVC.** Trace supported it (account_type `&.`-nil-safe; CCA readers start from an IVC; only break is `update_mece_market_tag`, an AngelList admin REST path). No-IVC implementation stands.

**Review gate progress (4-round budget):** Round 1 + Round 2 done, each 5 reviewers, NEITHER clean (counter still 0). Round 2 fixes applied (both fallout from the idempotency `find_by → .where.first` change): (1) a pre-existing race-condition test had gone vacuous — rewired to actually hit the RecordNotUnique rescue; (2) added FBO idempotency coverage (non-FBO not returned to FBO request; repeat FBO returns existing). Latest commit `e8d086624`, signed, 93 examples / 0 failures.

**OPEN — gating Round 3 (awaiting Kevin):**
1. KYC/auto-verify: NOVA FBO is `non_standalone_fbo?`==true (source 'nova' != 'standalone_banking') → auto-`verified: true`, skipping entity KYC + emitting TransfersEligibleEvent. Same as all AngelList fund FBOs; opposite of Standalone-Banking-source FBOs (KYC-gated). Need Kevin: gate NOVA or keep auto-verify? If keep, add a test pinning verified==true for NOVA FBO (reviewer flagged naming as misleading). If gate, small change to how 'nova' is classified — maybe own ticket (shared verification.rb).
2. FBO cardinality: idempotency assumes one FBO per (entity, purpose) — repeat returns existing. If NOVA opens multiple distinct FBOs per entity, key must include beneficiary/fund_lead.

**RESOLVED (2026-07-21):** cardinality = one FBO per entity (idempotency correct as-is). Verification: DO NOT touch auto-verify — NOVA runs on Increase GHB which has no KYC gate; transfer-eligibility is partner-specific; NOVA auto-verified is an intentional side-effect. No verification code change; no pinning test (would over-codify incidental behavior).

**Review gate: 5 rounds run (1 over the 4-round budget), 25 reviewer-agents. Core FBO logic clean since R2.** Fixes landed across rounds: NOVA fund_lead skip + never-Omnibus (resolve_fbo_program! honors program for NOVA), FBO-scoped idempotency, comment discipline, T.must→find_by! on NOVA honor branch (clean NotFoundError vs 500), spec coverage (race-rescue rewire, FBO idempotency, non-NOVA-no-program guard clause). Final commit `3b4248bbc`, signed, srb clean, 94 examples/0 failures.

**Open decision handed to Kevin (final gate item):** non-FBO→FBO idempotency mirror-leak (a non-FBO create could return a pre-existing FBO account). DECISION: leave non-FBO path unscoped = byte-for-byte pre-PR behavior, satisfies the load-bearing "non-FBO unchanged" invariant. Leak is PRE-EXISTING (FBO existed via REST pre-PR) + out of PR1 scope; naive `where.not(owner_type:FBO)` fix reintroduces a NULL-owner_type idempotency regression (MySQL `<>` excludes NULL). Recommend accept-as-is; optional follow-up ticket for platform-wide NULL-safe idempotency↔uniqueness-constraint alignment. Likely moot if NOVA FBO entity_ids disjoint from Venture non-FBO entity_ids.

**RESOLVED (2026-07-22):** issue is **BANK-1666** (its own issue, not a NOVA-3466 sub-issue). Branch renamed to exactly `kevinliang/bank-1666` (Kevin's canonical gitBranchName). Commit subject → `(BANK-1666 · 1/2)`, re-signed, final commit `4039867ef`. Mirror-leak ACCEPTED as-is: Kevin confirmed NOVA & Venture entity_ids never collide → practically unreachable. Linear MCP token kept expiring — couldn't fetch BANK-1666 myself; Kevin gave the branch name directly.

**SHIPPED (2026-07-22):** Kevin said "ship it". Pushed `kevinliang/bank-1666` (commit `4039867ef`, GitHub signature verified:valid), opened **PR #8305** (https://github.com/angellist/treasury/pull/8305) vs `main` via `gh api` POST. Body has `<!-- auto-generated by claude -->` markers + Claude Code footer.

**CI GREEN:** all 20 Buildkite contexts passed (build, sorbet, rspec 0-3, packwerk, brakeman, frontend, config-validate); semgrep + metabase green. Cursor Bugbot = neutral/advisory (non-blocking); depthfirst bot still running at handoff.

**Cursor's 1 finding** = the already-accepted non-FBO→FBO idempotency mirror-leak (create_service.rb:54). Pre-existing, out-of-scope, unreachable (entity ids never collide). DONE: posted won't-fix reasoning on the Cursor thread (PR comment discussion_r3634389207). No code change.

**Design Q (2026-07-22):** Kevin asked why FBO logic goes in shared CreateService vs mapping 1:1 with REST CustomerAccountsController. Answered w/ file:line: the two are already separate paths; controller#create builds inline + its FBO branch creates the full FUND cluster (InvestmentVehicleConfigurations::CreateService + IVC + mirror + ensure_ivc_exists!) — machinery NOVA standalone FBOs must NOT have. CreateService needed only ~4 lines (owner_type=FBO + build_fbo_identity, skip OwnerTypeService). Two parallel create impls = pre-existing tech debt; controller→CreateService convergence = possible follow-up ticket. **Kevin chose (a): keep PR-1 minimal.** Convergence NOT pursued.

**PR 2 (nova engbot rewrite) is separate and not this session's scope.**

Status: `srb tc` clean · 94 examples / 0 failures (`unset MOCK_ENTITY_API`, specs in-container `docker compose ... exec app`). prism app container was torn down mid-session once — `make up` in the worktree restores it. Bridge (Discord) intermittently timing out. See [[feedback_review-gate-five-reviewers]].
