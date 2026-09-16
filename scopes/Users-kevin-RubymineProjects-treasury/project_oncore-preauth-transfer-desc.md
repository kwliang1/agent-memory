---
name: project_oncore-preauth-transfer-desc
description: "PR #8702 — on-core preauth-credit regex now matches id-less \"Transfer\" descs (OC Upekkha)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 229463e0-4b3c-465f-a1b5-637048894a7b
  modified: 2026-08-27T21:01:33.534Z
---

PR #8702 (branch `kevinliang/ach-sync-oncore-desc-regex`, Slack-driven, no Linear). Widened `INTERNAL_ACH_GHB_ONCORE_ACH_ID_REGEX` in `app/services/treasury_prime/sub_accounts/ach_sync_service.rb`: keyword slot `(?:Payment|Transfer)`, ACH-id line optional `([0-9]{6})(?:\n(11[0-9a-z]+))?`. Non-capturing wrappers → `INTERNAL_ACH_GHB_ONCORE_ACH_ID_GROUP_NUM` stays 2, backwards-compatible.

**Why:** new on-core desc `"PREAUTHORIZED CREDIT\nOC Upekkha\nTransfer\n260818\nTransaction type: Credit"` has NO `11…` ACH-id line; it fell through to `IncomingWires::CreateService.create!` → double-counted an internal transfer.

**How to apply / key facts:**
- On the on-core path the regex is a *discriminator*, not the recon key. Match → `process_on_core_preauthorized_credits!` reconciles a pending `CrossTransfer`/`Transfer` **by amount_cents + state**, NOT by ach_id. The extracted id is only used in the orphan fall-through (already-completed check + raise message).
- Nil-id guard added: skip the `find_by(initiating_payment_processor_transfer_id: "ach_")` lookup when id absent; raise reads `ach_id=none`. Also added `TXN_IDS_TO_SKIP` escape hatch at loop top (mirrors incoming-ach-push path).
- Kevin confirmed these `Transfer` descs are internal → reconcile-or-raise is correct (external-shape collision accepted as non-issue).
- Not-fixable-in-code constraint: counterparty slot must stay `.*` because the discriminating value is a fund name (`OC Upekkha`), not a known internal label.
- Also deleted a dead `txns.select { OUTGOING_WIRE_PREFIX }` no-op in `sync_on_core_ledger!` (Array#select non-mutating, result discarded). Fossil of #3074 (removed on-core outgoing-wire sync) mangled by rubocop autocorrect in #4762 (Lint/UselessAssignment stripped the LHS). Documented in PR desc. Note: lint-staged rubocop also flipped `return nil`→`return` in adjacent `safe_parse_time` (unavoidable, disclosed).
- Open follow-up (predates this, unrelated): `OutgoingWires::CreateService.create_and_complete_for_on_core_account!` now has ZERO callers — on-core outgoing wires no longer discovered from TP feed since #3074; verify they're recorded elsewhere if concerned.
- Awaiting Kevin's explicit go-ahead to merge (not merged). Relates to [[project_bank1594-incoming-sla]] (on-core incoming-credit classification).
