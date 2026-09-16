---
name: project_bank1668-nova-ewa-entity-check
description: "BANK-1668 nova-managed EWA entity-consistency fix; PR #8306 up (enforce source==NOVA), gate passed, CI running"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5818e57f-f6ef-46cd-8196-38b84e3ad0a8
  modified: 2026-07-22T06:47:45.835Z
---

**BANK-1668** (High, assigned Kevin, team Nova Foundations/BANK) — fix model-layer destination-entity-consistency checks to be non-ipseity-aware for nova-managed ExternalWireAccounts. Driven by 2026-07-21 oncall: Capital Factory admin-fee wires, 10 transfers / $38,696.25 stuck; shared dedup EWA 91648 flipped to `nova_entity` but model validation (no nova carve-out) still rejected because `OutgoingPayments` was enabled ~5h prior.

Branch `kevinliang/bank-1668` (off main via treasury-flint worktree). Commit 7c2d95c0b signed+green.

**Root cause:** `validate_destination_entity_consistency` compares `origin.owner_entity_api_id` (ipseity id) vs EWA `entity_id`; for nova-managed EWA `entity_id` is Nova-space → spurious "entity does not match" reject. Fix = skip the ipseity comparison for `nova_managed?` (mirrors `OutgoingWiresHandler#create` app/handlers/outgoing_wires_handler.rb:42-48, which gates on `customer_account.source == NOVA`). `nova_managed?` (app/types/external_accounts/entity_id_type.rb) = NovaEntity + NovaDirectoryEntity (only those two; NO NovaDistributionPayment despite task-prompt claim).

**SHIPPED: PR #8306** (base main, branch kevinliang/bank-1668, auto-links BANK-1668). Gate passed (rounds C+D clean). 81 specs green, sorbet clean, signed. Final approach: for nova_managed? EWAs, ENFORCE `source == CustomerAccount::NOVA` (mirrors OutgoingWiresHandler) — Kevin chose enforcement over blanket-skip so the legacy REST wire path keeps a model backstop. OW guard `ca.present? && ca.source != NOVA`; OP `origin.source != NOVA` (origin nil-guarded at top). Follow-ups NOT in PR: ACH branch same gap (Nova ACH live via ach_pushes_handler); GraphQL OW mutation inline ipseity check (mutations/outgoing_wires/create.rb:80-83) still blocks nova.

**Build history (committed 2e388e158→amended, signed, sorbet clean):**
- OP: `app/models/outgoing_payment.rb` — guard at top of `when ExternalWireAccount`.
- OW: `app/models/outgoing_wire.rb` `validate_consistent_customer_account` — guard after `return if ewa.blank?`, before dedup fork (preserved the [EWA Dedup Migration] comment). Kept sig-less to match sibling validators (file typed:true, all validators sig-less).
- Specs both files: load-bearing dedup-nova parameterized over NovaEntity+NovaDirectoryEntity; OP also keeps non-dedup ipseity mismatch.

**PENDING Kevin's call — design fork (asked 2026-07-21, holding push):**
Round-A review found: 3 wire-creation paths gate entity-ownership differently. Prophet handler gates `customer_account.source == NOVA` (safe). GraphQL mutation (mutations/outgoing_wires/create.rb:80-83) has own inline ipseity check, no nova carve-out → still rejects nova (broken-but-safe). **Legacy REST (api/outgoing_wires_controller.rb#create, route live routes.rb:280) has NO entity gate** — relied solely on the model validation. So blanket `return if nova_managed?` removes the only backstop for dedup nova on REST.
- **My recommendation:** switch both guards from blanket-skip to ENFORCE `origin/ca.source == CustomerAccount::NOVA` (source='nova' exists, customer_account.rb:50) for nova EWAs — mirrors handler, keeps backstop on REST, more faithful to "don't blanket-disable."
- Alt: keep skip, ticket the REST gate separately.

**Follow-ups (not in this PR unless Kevin says):**
- ACH branch of OP method has same latent gap; Nova ACH live (ach_pushes_handler.rb:34-39,83,156).
- GraphQL OW mutation inline ipseity check needs same nova treatment (nova wires via GraphQL stay broken).
- Continuation Slack thread (p1784700196403559) not read — may refine scope. See [[feedback_review-gate-five-reviewers]], [[reference_al-console-treasury-rbac]].
