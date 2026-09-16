---
name: bank653-carry-recipient-fk-gap
description: BANK-653 carry-recipient routing is only half-fixed — venture #32719 abstains on multi-syndicate GPs; #26765 reopened to close it.
metadata:
  type: project
---

Carry payment routing in venture/CPTR has a **partial** fix deployed, and the remaining gap is exactly what BANK-653 describes.

**Shipped:** venture #32719, merged 2026-08-11 (`84d2ef9a54f`, on `origin/main`). CPTR reads venture's `syndicate_carry_recipients.treasury_id` FK before falling back to the old entity+purpose lookup. Entry point `backend/cptr/app/services/cptr/payments/info_service.rb:159` → `linked_carry_recipient_account` (:305) → `Syndicates::CarryRecipients::InfoService.treasury_account_id`. Motivated by INC-5441 (ops pointing carry recipients at MANAGEMENT_COMPANY-purpose accounts, ~$190k stranded), NOT by the multi-syndicate ambiguity.

**The gap:** that helper keys on entity alone and does `treasury_ids.one? ? treasury_ids.first : nil` — it abstains whenever a GP is a carry recipient in 2+ syndicates, falling back to the arbitrary `TreasuryAPI::CustomerAccount.all(...).last`. #32719 counts 47 such entities; BANK-653 counts 208 entities with >1 non-FBO CARRY_RECIPIENT account (different denominator: carry-recipient rows vs treasury accounts). Canonical case: Paige Craig, GP in both her own syndicate and Arena Ventures.

**Not fixable by merging the accounts** — treasury blocks it in `CustomerAccounts::MergeService` and the uniqueness index is INVESTMENT-only.

**Reopened 2026-08-31:** venture #26765 (INC-4220) keys on `(entity_id, syndicate_id)` via `payment → distribution → membership_class → ComptrollerExport → FundraisingCampaign → Syndicate → CarryRecipient`. Closed unmerged 2026-05-28 after Stathis pushed for structured-data FKs instead. Now `mergeable_state: dirty` — #32719 rewrote the same method, so it needs a rebase and should reuse `linked_carry_recipient_account`'s validations (active / owner match / non-coinlist / 404 falls through) rather than a bare `.find`.

Datadog can't answer "is venture deployed" — `service:venture` returns only auth-service client spans, and there are no GitHub deployment records or deploy workflows. Fall back to merge-date + commit count on main.

Related: [[nova-transfer-balance-reservation-traps]], [[treasury-link-existing-increase-ca]]
