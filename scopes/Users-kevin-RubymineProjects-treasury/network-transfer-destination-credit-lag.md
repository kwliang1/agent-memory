---
name: network-transfer-destination-credit-lag
description: "TP NetworkTransfers credit the destination bank days before TP status leaves `processing`; BANK-1594's expected_to_settle classifier exists but fails on mixed landed/unlanded credits (full-sum vs subset-sum) — CA 225873 case."
metadata: 
  node_type: memory
  type: project
  originSessionId: 19d9b6d6-1e01-45fd-808b-4f0c2036f1d6
---

Investigated 2026-07-12 (CA 225873, Piermont Crypto SA 398424): weekend balance-check flags with diff $219,999.99 = exactly 3 TP NetworkTransfers (GHB Main → Piermont Crypto) submitted Fri evening — Piermont credited within hours, TP status stayed `processing` (settles Mon; NT SLA `payment_sla.yml:53-60` warn 4bh/crit 8bh is business-hours, pauses weekends).

Key facts:
- NT completion is driven ONLY by TP status → sent/complete (webhook or `sync_transfer_states` 30-min cron → `ReconciliationService`). NTs excluded from the incoming-txn arrival matcher (INC-4851). Cross-bank NT destination credits are visible at the bank **days** before completion — the one payment type where #8146's "no observable destination window" fails (ACH/wire analysis still holds).
- **Kevin already shipped the classification feature** — BANK-1594: #8185 + #8186 merged 2026-07-10 (do NOT re-propose it): non-adjusting credit rows (IncomingWire provisioned/hold, unbridged DIBS credits, ALL pending V2 incoming), `explained_by_pending_activity?`, resolved-class `expected_to_settle` status, past-critical → `needs_review`. #8187/#8194 were closed-folded into #8186.
- **The residual bug (found + FIXED 2026-07-13)**: full-sum-only matching never classified accounts holding both landed and in-transit credits. **Shipped as BANK-1622 / PR #8211**: match ladder :full_sum → :confirmed (IncomingWire/DIBS rows mandatory) → :subset (bounded deterministic search over Transfer rows only, fails closed on cap/unknown-provenance/non-positive amounts); match-kind-tagged metric + sub_account-identifying log. Prod replay: 13 accounts / 65 records flip (all Transfer-type rows). BANK-1624 tracks the persistence monitor (subset-matched accounts, esp. nil-SLA FUNDS_MIGRATION rows that never breach).
- LESSON (stress-test yourself): my checkout was 5 commits stale and I proposed rebuilding what #8186 had shipped 2 days earlier. Always `git fetch` + survey merged/open PRs (`gh pr list --search`) before proposing or building. Kevin's "stress test yourself" = check the deployed code, not your mental model.

Ops notes: prod read console lacks TP API config (write console `-w` needs an SSO browser prompt Kevin must approve). Shared checkout sits on someone's branch with stashes — read origin/main via `git show`, never pull it.
