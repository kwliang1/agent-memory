---
name: project_bank1508-mmf-confirmation-key-fix
description: "BANK-1508 executed — PR #8366 fixing MMF buy+sell confirmation-download symbol/string key bug"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5b79408f-71b9-4055-9195-d1fa814dc99d
  modified: 2026-07-27T23:11:12.667Z
---

BANK-1508 (Nova Foundations / MMF v2, M6 cleanup): verify-before-build confirmed it was **genuinely not-done** on real `origin/main` (unlike several stale sibling tickets) — intervening MMF merges #8026/#8320 did not touch it.

**Bug:** `MoneyMarketFundAccounts::OrderService#download_mmf_buy_confirmations!` (`app/services/money_market_fund_accounts/order_service.rb`) called `.deep_symbolize_keys` on the FREC deposits response, then accessed it with STRING keys (`dep['id']`, `.dig('orderConfirmation','tradeConfirmationDocumentUrl')`) → always nil → `find` never matched → `nil.dig` raised NoMethodError. Buy confirmations never downloaded. Latent (MMF orders not exercised in prod yet).

**Bonus finding (not in ticket):** `download_mmf_sell_confirmations!` one method below had the identical root cause — `deep_symbolize_keys` + `response.dig('liquidation',...)` string keys → url always nil → silently never downloaded. Fixed both in one PR.

**Fix (PR #8366, branch `kevinliang/bank-1508`, commit dde69b3df signed+pushed):** drop `deep_symbolize_keys`, use the `.with_indifferent_access` hash with string keys consistently (matches sibling `refresh_*` methods; `get_frec_deposits` already returns HWIA); add `&.` nil-safety on buy lookup. Added 4 specs (match+upload, graceful-skip for buy & sell). 26 examples green, Sorbet clean. Real `Frec::Client` returns `JSON.parse` string-keyed hashes, so HWIA is correct against prod, not just mocks.

**Gate:** 3 rounds. R1 (5 agents) flagged over-fit sell-spec scaffolding (`:with_balance`/`mmf_holdings`/`buy_position_entry`/`funded_by_mmf_position` transfer — I over-copied from the refresh-sell block; download only needs a WireCompleted Sell + factory-default transfer). Simplified → R2 (3 agents) + R3 (2 agents) both clean = 2 successive clean rounds.

⚠️ First cron run after deploy processes the full OrderCompleted/WireCompleted backlog in one pass (no flipper); idempotent via state filter. See [[feedback_mutation-agents-corrupt-worktree]] — a review agent dropped/recreated this worktree's test DB (`treasury_test_pixel`) mid-session; recreated via `make setup-worktree` + `RAILS_ENV=test db:create`; HEAD/source never at risk.

**CI red on #8366 is NOT my code.** All 17 shard-2 (`rspec-treasury-2`) failures were in `spec/tasks/maintenance/recreate_legacy_mmf_ct_orders_task_spec.rb` (from #8320/BANK-1493), which I never touched and which has zero coupling to OrderService (grep-confirmed). Treasury shards rspec via KnapsackPro Queue mode (see [[reference_treasury-knapsack-queue-mode]]) — my 4 added examples reshuffled node co-location, surfacing a latent isolation bug in that maintenance spec (whole-file failure; `#collection`/`#process` read via reading-role, invisible to fixtures under `:transaction` cleaner). My worktree can't faithfully run that spec (fails under both transaction AND truncation locally — env confound), and Datadog CI Visibility has no treasury rspec data. Recommended to Kevin: rebuild the shard (queue redistributes); if it re-fails, that spec needs its own isolation fix (separate ticket, not BANK-1508). **Resolution:** dusk's PR #8369 (merged as commit a6f82f99c, "**repair** RecreateLegacyMmfCtOrdersTask spec after CT-rail retire" — repaired, NOT deleted; both files still on main). Rebased #8366 onto new main → commit **d9bd1d93d** (signed, `git rebase --gpg-sign origin/main`, clean no-conflict, diff unchanged = 2 files), force-pushed. Fresh CI build #32073 running; my spec green on rebased tree (26/0). Kevin then asked to formalize sell scope: sell CODE was already fixed from commit 1 (order_service.rb:277), so I only updated **Linear BANK-1508** (retitled "…MMF confirmation downloads (buy + sell)", rewrote problem/fix for both methods) and **PR #8366** (title "…buy + sell…", desc re-framed sell as first-class not bonus) via `gh api PATCH`. **#32073 PASSED green** (all rspec shards incl. previously-red shard 2) — CI cleared purely by the rebase onto repaired main; my diff never changed. PR #8366 green + mergeable, awaiting Kevin's merge. DONE.
