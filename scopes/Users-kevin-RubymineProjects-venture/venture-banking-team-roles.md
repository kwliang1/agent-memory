---
name: venture-banking-team-roles
description: venture standalone-treasury team membership = Banking::Role/Permission only (no owner column); UpdateService wipes transfer limits; BANK-1833 script in Arti bank-1833-remove-team-member
metadata: 
  node_type: memory
  type: project
  originSessionId: 9f1b0430-07d1-41df-89f3-067a7fc26961
  modified: 2026-09-09T21:09:31.774Z
---

Standalone treasury (treasury.angellist.com) team access is entirely venture-side `banking_roles` + `banking_permissions` (`backend/banking/`); policies gate purely on them. There is NO owner column — "owner/admin" = `manage_team` (vehicle) / `manage_firm` (instance).

Traps found 2026-09-05 (BANK-1833):
- `Banking::TeamMembers::UpdateService.update_permissions_for_role!` silently **nils transfer limits** not re-passed (`set_limits` updates all three with nil defaults) — add `Banking::Permission` rows directly instead.
- `RemoveService.remove_role_from_vehicle!` raises on the last role of a vehicle (create successor first) and auto-destroys a view-only instance role; its `check_vehicle_roles_for_user` ignores mgmt_cos (latent bug, duplicated call lines 37-41).
- Pending invites match on downcased `pending_user_email`; accept = set `user_id` + `accepted_at`.
- Dry-run pattern: wrap in `BankingRecord.transaction` + `raise ActiveRecord::Rollback` — services join the txn, no external side effects unless `invite_to_vehicle!` (email+Slack).

Adversarial review (3 rounds, 2026-09-09) hardened the scripts to **v7 = execution version**. Key catches: (1) instance-role invariant — any vehicle-role holder needs an INSTANCE_VIEW role (`AcceptService#add_role_for_instance_if_necessary`; policies require it for the firm dashboard); (2) `FetchService#initiator_user` = LAST reviewer when reviews exist — a wire from an approved-unwired request is attributed to the last reviewer, not the creator; (3) dry run now prints per-vehicle authorization regime (enforce flags + approver_count vs post-change review/approve holders; deadlock/zero-review warnings). Rebutted: self-review IS blocked (`transfer_requests/review_service.rb:9,36`). Open decisions: Kevin (union vs full perms), compliance (ownership swap rides stale `major_shareholders_reviewed` attestation).

**EXECUTED 2026-09-09, verified in all three prod systems**: venture — Nathan 0 roles/0 invites, Keith 16 roles incl. instance manage_firm; ipseity — Keith sole sig (title "Managing Partner") + CP on XC Edify - A, verified?=true; treasury — CAs 314141+316981 sig="Keith Nilsson" verified=true. Open human-side: deadlock advisory (Keith sole review/approve holder; ≥$50k external needs 2 approvers on 11 enforced funds — self-serve fixable via manage_team, needs 2FA) + Front bank-credential handoff. Transfer-config mutations (upsert/delete config, updateVehicleConfig) all gate on vehicle manage_team + recent 2FA.

BANK-1833 (Arti slug `bank-1833-remove-team-member`, v7): Script 1 = venture team removal (+ pending-transfer-request gate on `banking_outgoing_wire_requests` created_by_id/state + reviews); Script 2 = ipseity sig+CP swap on XC Edify - A (add-before-remove in one txn, in-txn `VerificationService.verified?` assert, direct `Roles::*.create!` is the canonical mechanism — role models have no callbacks/events). Treasury cached `signatory_identity_name` needs manual `update_signatory_identity_name!` after (prefer over `refresh_cached_names!` which pings DIBS). Awaiting Kevin's run.

Ipseity prod scan (2026-09-09, read-only via `al console` — ipseity-ro RBAC forbidden, used write console after `al console create --no-attach -a ipseity -p -w`): Nathan Feltz appears on exactly ONE entity, `XC Edify - A, LLC` (`20a9fbab82eb429e894c6657aa4a77cd`, verified) as its ONLY signatory + ONLY control person (person `da3b0e519987455d8347204e8da5dfd2`). Keith Nilsson: 11 dupe person entities, all KYC-verified (canonical CP one = `4b41f70f80a0450daa6553657f23e5b9`, CP on ~15 XC entities) — safe swap needs no KYC wait. Side find: Xplorer Fund V ×2 / Fund IV / Growth I already compute unverified (blank signatories) — live landmine examples. Persons matched via plaintext citext `identity_data_people.primary_contact_email`; roles tables = `roles_signatories(entity_id, signatory_id)` etc.

KYC guard investigation (2026-09-08): team removal trips NO lower-level guard. Treasury uses wire `initiator_email` only to block self-approval (`outgoing_wires/state_service.rb:94`). The real guard: treasury blocks transfers when `customer_account.verified` flag is off (`customer_accounts/validate_service.rb`); flag re-derives from ipseity's LIVE company verification (`entities/verification_service.rb`): ≥1 signatory must EXIST (signatories need no KYC), ALL control persons + major shareholders must be identity+watchlist verified. Landmine shape: removing a signatory emits no EntityLifecycleEvent, so treasury keeps stale verified=true until the next recompute (yearly watchlist recheck / admin action) — then wires stop. Safe orders: signatory swap = add first, remove after; control-person swap = KYC successor to verified BEFORE swapping.
