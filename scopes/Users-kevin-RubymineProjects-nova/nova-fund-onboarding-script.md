---
name: nova-fund-onboarding-script
description: "Nova fund bank-account onboarding — the ipseity+treasury script pattern, two signatory paths, and the control-person==signatory convention."
metadata: 
  node_type: memory
  type: project
  originSessionId: 72188d2e-473b-4ab8-bb27-abceb8063456
  modified: 2026-07-29T05:37:52.646Z
---

Nova "open a bank account for <fund>" tasks (Linear project "Nova Fund Onboarding Tasks", e.g. NOVA-3492 Tricky Knot) come from a Flowdash task with Fund / GP Entity / Control Person cards. Kevin writes a `rails runner` scratch script per fund under `~/Library/Application Support/JetBrains/RubyMine2025.3/scratches/nova/onboarding/<org>/`.

**Run env:** the **treasury** console — it has BOTH the ipseity client SDK (`EntityAPI::…`) and treasury models (`CustomerAccount`, `PartnerBank::Program::MigrationService`). Not ipseity's own console.

**Two signatory/control-person paths:**
- Already on platform → link an existing entity id via `EntityAPI::Roles::Signatory` + `Roles::ControlPerson` (old bulk_onboarding / capital_factory pattern).
- NOT on platform → create fresh: `FirmData.fill` spawns a phantom Person signatory, then `EntityAPI::ClosingFlow::SignatoryData.fill(entity_id:, first_name:, last_name:, dob:(TimeWithZone), phone:, tax_id:(=SSN), primary_contact_email:, address_*)`, then `EntityAPI::ClosingFlow::EntityOwnershipData.fill(entity_id:, signatory_is_control_person: true, should_confirm_roles: true, skip_kyc_checks_on_create: true)`. Canonical example: `capital_factory/multi_fund_onboarding.rb`. Param names verified against `ipseity/entity_api/definitions/entity_api/messages/closing_flow.proto`.

**Control person == signatory** historically (Flowdash has an "Is control person the signatory? Yes" field). It's a natural person, NOT the GP entity.

**GP entity is NOT a treasury input.** For a Delaware LP the control chain is Fund LP → GP LLC → natural person; the GP info on Flowdash is KYC/CIP documentation (control-person authority) + AML-service-provider designation, consumed by the downstream "Send KYC Review Task" step, not by the ipseity entity or treasury CustomerAccount. Only fund (owning entity) + control person are wired into the script.

**Common Flowdash gaps** to fill before running: control person DOB and *residential* address are often blank; the person's address may legitimately be the same as the fund's (Kevin confirmed for Tricky Knot). SSN is behind a SendSafely link — never open it, use a `tax_id:` placeholder Kevin fills at run time.

**DOB is REQUIRED for US-person identity verification** — not Alloy-specific. The shared gate `Entities::Verifications::AlloyService.can_verify_person?` (ipseity `app/services/entities/verifications/alloy_service.rb:63-78`) requires first_name + last_name + **birthdate** + address.street1/city/country + (US ⇒ ssn). Blockscore & Persona identity services call the same `can_verify_person?`. If any is missing, `verify!` (`alloy_service.rb:17`) `return`s early — a **silent skip**, no error, person left unverified (trips `control_persons_verified?` downstream). Older scripts that ran with `dob: nil` silently skipped person verification. Treasury side (`create_treasury_account`): create FBO `CustomerAccount` (source NOVA, purpose INVESTMENT) → `FboIdentity` → migrate to Piermont (DIBS_PIERMONT_STANDARD_DEPOSITS_PROGRAM) → wait for async SubAccountRequest before IVC. Script ends by printing a JSON payload (`orgHandle`, `funds[]` with ipseityEntityId + treasury uuid/subaccount) to paste into the Nova JS console.

**`cleanup_entity` rollback helper is BROKEN in the treasury console** (verified 2026-07-28 in treasury staging): it references bare `Entity` / `Roles::Signatory` / `Roles::ControlPerson` / etc. — those are ipseity *server-side* models, uninitialized constants in the treasury runtime (which only has the `EntityAPI::` SDK client). `EntityAPI::Entity` has no `destroy` either. So a failed run can't be rolled back from where the script runs — clean the ipseity entity from an *ipseity* console (bare models) and the treasury `CustomerAccount` separately. All the scratch scripts in the folder carry this same broken helper.

**Cheap pre-run validation** (read-only, no PII): push a `respond_to?`/`const_get` load-check to a treasury staging console (`al console create -a treasury -e staging`; default env is staging, read console is default) and rails-run it — confirms every `EntityAPI::`/`CustomerAccount`/`PartnerBank` method+const the script calls resolves in the real runtime and the Piermont `PartnerBank::Program` row exists, before touching prod.

Related: [[flowdash-treasury-ca-creation]], [[treasury-link-existing-increase-ca]], [[treasury-prod-console-access]].
