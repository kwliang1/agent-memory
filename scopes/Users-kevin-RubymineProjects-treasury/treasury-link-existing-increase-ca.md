---
name: treasury-link-existing-increase-ca
description: "How to link a pre-existing Increase account to a Treasury CustomerAccount (INTERNAL_FINANCE etc.) — no service path exists, use create_from_dibs_webhook!"
metadata:
  node_type: memory
  type: reference
  originSessionId: 864633f7-58e5-47b5-b552-a2875aa193a3
---

Investigated 2026-07-09 (fern session) for Bisher's ask: create an INTERNAL_FINANCE CustomerAccount owned by ALAM, linked to an existing Increase account. See [[flowdash-treasury-ca-creation]] for the general CA-create surfaces.

**Key finding — there is NO service/API/GraphQL path that *links an existing* Increase account.** `CustomerAccounts::CreateService.create!` and every DIBS open flow (`DIBSApi::InternalAccountsService.create!`) *provision a brand-new* account. The only "attach a known account number" helper is BNY-only (`SubAccounts::CreateService.create_manual_bny_dibs_sub_account!`). So linking a finance-created Increase account is a bespoke console job (Kevin did this by hand Jul 1).

**The linking primitive:** `SubAccounts::CreateService.create_from_dibs_webhook!(customer_account:, partner_bank_program:, dibs_internal_account_id:, account_number:, routing_number:, account_holder_name:)` (`app/services/sub_accounts/create_service.rb:201`) — same call the DIBS approval webhook uses (`app/public_api/treasury_app/notification_service.rb:129`). Sets the sub-account active.

**How a SubAccount references its Increase account:** `sub_account.dibs_internal_account_id` → `DIBS::InternalAccount.external_account_id` = the `account_...` id in the dashboard.increase.com URL. `DIBS::InternalAccount` (real AR model in `backend/dibs/`) has that column **uniquely indexed**, so you can resolve everything from the URL id: `DIBS::InternalAccount.find_by(external_account_id: "account_...")`.

**Recipe to link (verified against code):**
1. `dibs = DIBS::InternalAccount.find_by(external_account_id:)` — raise if nil (means not onboarded to DIBS yet).
2. Program: `PartnerBank::Program.find_by!(name: PartnerBank::Program::DIBS_PARTNER_BANK_MAP.key(dibs.partner_bank_fbo.name))` → `DIBS_INCREASE_GHB_NAME` (fbo name = `'Increase (Grasshopper Bank)'`).
3. Build CA with plain `CustomerAccount.create!(owner_type: CustomerAccounts::OwnerTypeService.for_entity(entity), owner_entity_api_id:, source: 'angellist', account_purpose: 'INTERNAL_FINANCE')` — NOT `CreateService` (it would provision a new GHB account). Only `after_create` on CustomerAccount is a log line, so `create!` provisions nothing.
4. `create_from_dibs_webhook!` with the dibs fields.
5. **Attach FIRST, then `ca.update_verification!`** — with a sub-account present, `create_sub_account_for_previously_blocked_if_applicable!` early-returns (`sub_accounts.any?`), so verification can't spawn a stray account; it just marks verified + emits transfers-eligible.

Control person is NOT a CA field — `owner_control_persons` derives from the owner entity's Ipseity relationships. `should_open_dibs_sub_account?` is Piermont-LP-only, irrelevant to INTERNAL_FINANCE.

Draft maintenance task (parameterized, maintenance_tasks 2.17.0 supports `attribute`): scratchpad `link_existing_increase_customer_account_task.rb`.

**PROD VERIFICATION 2026-07-09 (via `al console exec -a treasury -p -- bin/rails runner`, read-only) flipped the premise:**
- Kevin's "this is live" reply was WRONG/misremembered — **the requested CA was never created.** ALAM = entity `47fd9a3b82af40d9ac5922cfc57c4920` = "AL Advisors Management, Inc"; its newest CA is id 447240 (2026-04-22), nothing after. Bisher asked Jun 30.
- Increase acct `account_a6bhkyvn7tmejyvoglzk` referenced NOWHERE in Treasury: 0 DIBS::InternalAccount, 0 ExternalAchAccount, 0 ExternalWireAccount. So it is NOT DIBS-onboarded — my link recipe's precondition fails for it.
- The "similar" CA 73961 is INTERNAL_FINANCE for ALAM but on **Grasshopper Bank Main = Treasury Prime** (tp_ext acct_11j2c0dt1b1jpsr), created 2020 — NOT Increase-backed.
- OPEN with Kevin: is interest income/fee-pull flowing through the Increase acct directly (ask moot, no Treasury CA needed) or did the task fall through (real gap)? Rebuild recipe only after that + only if Increase acct gets DIBS-onboarded.

**`al console` prod read access works** for this bridge session: `al console create -a treasury -p --no-attach` then `al console exec -a treasury -p -- bin/rails runner '<ruby>'` (read-only default; `-w` for write). Console `console-read-kevin.liang-0`.
