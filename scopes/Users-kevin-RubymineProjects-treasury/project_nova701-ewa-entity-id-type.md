---
name: project_nova701-ewa-entity-id-type
description: "treasury #9163 (NOVA-701 treasury half, 2026-10-14): EWA index by customer_account_id no longer needs entity_id; Counterparty::Wire carries entity_id_type; gem 0.8.8. What was deliberately left out and why."
metadata:
  type: project
---

Treasury PR #9163 on branch `kevinliang/nova-701` (pushed 2026-10-14 after a 3-round gate; rounds 2 and 3 clean). Nova half of NOVA-701 is still Yewon's.

**Shipped:** `external_wire_accounts.index` by `customer_account_id` finds the CA by uuid and ignores `entity_id` (legacy guard removed per [[project_pr9139_bulk_details_review]] and the #9160 skill section). `Counterparty::Wire#entity_id_type` is a non-nilable `String`, set at all three constructors (`ExternalWireAccount#to_prophet_output`, `OutgoingWire#to_recipient_details_output`, `OutgoingPaymentsHandler#recipient_details`); round 1 caught that I had only set the model one.

**Deliberately not done:** ACH index still has the same `entity_id` guard and `Counterparty::Ach` lacks `entity_id_type`; ticket named wire only; skill documents both as legacy-not-to-copy. Nova's Zod schema does not declare the field yet; nova's `EntityIdType` type already has all three values.

**Trap for nova:** the CA branch can never return a nova-owned EWA because `CustomerAccounts::InfoService.resolve_for_external_account_create!` nils the CA for `nova_*` owners. Nova-owned rows are entity-only (`deduplicated: true`) and must be listed via `entity_id` + `entity_id_type`. Written into the CHANGELOG and skill.

**Why:** the `Counterparty::Wire` miss was a copy-paste identity block in three places; the non-nilable type is what stops the fourth. Kevin also asked that the rule be persisted in the skill, not just the PR.

**How to apply:** when nova's `provision/wire.ts` moves to `ownerOf`, point it at the entity branch, not `customerAccountId`. If ACH gets the same treatment, mirror this PR as one patch bump.
