---
name: bank-1506-imad-omad-trace
description: "BANK-1506 IMAD/OMAD trace — treasury PR MERGED; venture PR #31974 SHIPPED to ready-for-review (rebased/redesigned/green), NOT merged"
metadata: 
  node_type: memory
  type: project
  originSessionId: 12cd1de1-41ef-4e32-9174-9ecf9e07852f
  modified: 2026-08-21T20:20:34.402Z
---

BANK-1506: expose wire IMAD/OMAD + ACH trace numbers on the funding accounts page (LP-facing, end users not admin-only — per the Slack thread linked in the Linear issue). Two PRs.

- **treasury #8375** — MERGED (2026-08-04). Prophet RPC `transfers.trace_details`. Reads `OutgoingWire.metadata.imad/omad` (Treasury Prime path) w/ DIBS fallback; ACH = `partner_bank_trace_number` (/\A\d{15}\z/) or DIBS. `authorize_entity!` binds `customer_account.owner_entity_api_id == entity_id` (foreign transfer_id → Forbidden).
- **venture #31974** — **2026-08-21: UN-PARKED and SHIPPED to ready-for-review** (branch `kevinliang/bank-1506`, head `be4114da`, signed, **CI GREEN**, NOT merged — awaiting review/merge). Worktree `.worktrees/venture-1506` (left in place).

**What the 2026-08-21 session did (the whole "post-merge one-shot" + more):**
1. Rebased onto current main (**793 commits**; repo was shallow → had to `git fetch --deepen`). 2 conflicts: `Transactions/index.tsx` (kept both main's `useTransactionFilters` + trace-blade plumbing) + `schema.ts` (regen; dropped a stale dup `Unauthenticated…Query` block). Gem/RBI already in sync (rebase carried treasury_prophet_api 0.7.0@1d8f33 w/ trace_details + its RBI) — the memory's "bundle update + make gem-rbis" step was a NO-OP.
2. **Redesigned the blade** (Kevin: original was "ugly") to mirror nova's `TransferControls/TransferDetailBlade` (adapt `Card` + `SimpleTable`: Method chip + IMAD/OMAD/trace rows), pared to LP-visible fields. Precedent owner = nova TransferControls (yewon/ywplee-al).
3. Review gate: 4 agent-passes + Cursor Bugbot. Fixes: cached-number survives a failed revalidation (last-assigned `useRef`, reset inline on row change — covers both network-error AND resolver-null clobber); body extracted from IIFE to named `TraceDetailsBody`; nowrap values; count-aware "these/this number(s)"; card-shaped skeleton.
4. CI fixes: rubocop `Sorbet/StrictSigil` (new files must be `# typed: strict` — resolver got `@args = T.let(...)` + `T.must` pattern, type was field-only so just the sigil); sorbet `srb tc` real error (`transfer_type` nilable past the TRACEABLE guard → `T.must`). This sorbet error was the original `sorbet-angellist` red.
5. **Live e2e validated** (Kevin OK'd full-stack takeover): booted worktree monolith :3001 + fundraising :3003, reused running treasury :7020, seeded `OutgoingWire.metadata.imad/omad` on a Tonic LP wire (naval/entity 309, wire 1575), drove admin + non-admin-LP (impersonated) blade → screenshot in PR body. **Local treasury execution-adapter is FLAKY** (intermittent "Transfers API error" from `TransferDetailsService.transfer_type` adapter lookup — retry; not a code bug). Screenshot upload = GitHub composer → `user-attachments` CDN (not committed).

**Local dev gotchas learned:** venture funding-accounts URL = `/v/:userSlug?/i/:investAccountSlug?/funding-accounts/:entitySlug?` (fundraising Next.js under nginx `/v/`→:3003, everything else→:3001; deps-nginx-1). Admin can view any LP's dashboard via the slug URL ("viewing as admin"); full impersonate via footer "Log in as X" (ends via "Log out" → `session.delete(:impersonate_user_id)`, returns to admin). GraphQL is SSR (node→monolith), not browser XHR. Big-ledger LPs (300+ txns) render slowly. Funding-accounts rows are treasury `TreasuryAPI::Transfer` ledger entries; `transfer_id = requester_id`; only OUTGOING_WIRE/ACH_PUSH/ACH_PULL get `transfer_type` (else nil→no button). Test DB needs `rake db:test:prepare` after rebase or specs cascade-fail. CI rubocop: `bin/ci/rubocop_changed_files.sh` (`--fail-level error`, so C/W offenses don't fail) + `rubocop_new_files.sh` (`--only Sorbet/StrictSigil`, specs excluded). Commit needs `--gpg-sign --no-verify` (rebase strips signature; broken husky); `%G?`=N is just missing allowedSignersFile, check `git cat-file commit HEAD | grep gpgsig`.

**Cleanup done 2026-08-21:** treasury seeds reverted (Metadata 2084/1180→nil), impersonation ended, worktree stack stopped, Kevin's mmf-ivc overmind restored (sidekiq/webpack/monolith/fundraising/banking).

**Still open:** (a) Devin "chaos testing" — Kevin asked to invoke it; need exact trigger (public PR comment). (b) file `recipient_details` IMAD/OMAD gap (`OutgoingPaymentsHandler#recipient_details` omits imad/omad on OutgoingPayment branch) as own ticket? (c) worktree teardown. See [[treasury-local-dev-gotchas]], [[nova-worktree-dev-gotchas]].
