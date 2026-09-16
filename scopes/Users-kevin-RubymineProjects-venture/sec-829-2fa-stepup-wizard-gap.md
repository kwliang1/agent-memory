---
name: sec-829-2fa-stepup-wizard-gap
description: venture #34947 (SEC-829) adds backend 2FA step-up to transfer-config delete/import/purge; guard is correct but the NthVehicleSetup wizard has NO FE step-up, so it fails silently.
metadata:
  type: project
---

venture PR **#34947** (Devin, SEC-829, branch `devin/1788770134-sec-829-delete-trc-2fa`, OPEN as of 2026-09-14). Adds `require_recent_2fa_if_mandatory!` to `Banking::Mutations::BaseRelayClassicMutation` and applies it to `DeleteTransferRequestConfig`, `Settings::ImportExistingVehicleTransferRequestConfigs`, `Settings::PurgePrevImportedVehicleConfig`.

**Backend guard is justified** (Kevin's "it's just new-vehicle setup, why 2FA?" premise doesn't hold):
- The import mutation with `prev_import_*` args is a DESTROY path — `RemoveService.purge_prev_tr_configs_from_vehicle_config!` (`remove_service.rb:6-21`) destroys matching dest configs then recomputes `enforce_*_transfer_request_configs` from survivors. Flags going false → `fetch_service.rb:97-101` → transfer type needs no approvals. Same end state as the delete gap.
- Nothing scopes dest_vehicle to a vehicle in setup; it's slug-resolved (`import_...rb:18`, `purge_...rb:15`). Direct API call works against a live fund.
- Not even new-vehicle-only in UI: `redirectToCorrectFundSetupPage` (`frontend/banking/lib/redirects.tsx:456-489`) has no completed-setup guard.
- Callers DO have the permission — `manage_team?` = `VEHICLE_MANAGE_TEAM` (`banking/fund_policy.rb:18-26`). Guarding delete but not purge makes purge the bypass.

**KEY REUSABLE FACT — how venture banking 2FA step-up actually works:** the FE does NOT handle the `:unauthorized` error. It PRE-EMPTS it by calling `getValidTwoFactor()` (opens `ValidateTwoFactorModal`) BEFORE the mutation — `Security/TransferRequestConfigs/index.tsx:85,112,130`, `Security/UpsertModal/index.tsx:60,110`, `Security/index.tsx:49`. Backend raise is only a backstop. The PR body's claim "the frontend already handles the same `:unauthorized` error" is FALSE.

**The real defect:** zero `getValidTwoFactor` hits under `frontend/banking/containers/NthVehicleSetup/`. Plus no error handling — `ImportDecisionSelectList/index.tsx:20-53` fires from a bare `useEffect` (no await/catch/onError) and Apollo has no `onError` link (`pages/_app.tsx:52-59`) → silent no-op. `VehicleSelectionSelect/index.tsx:79-141` is worse: team-member import succeeds at :81, purge throws at :108, catch at :134 only logs + blanks the selection → partial apply, no user message.

**Blocker for the FE fix:** FE has no `isMandatory` signal — `twoFactorConfig` exposes only id/hasAuthenticatorApp/lastValidatedAt/phoneNumber (`app/public_api/venture_app/two_factor_config.rb:60-65`), and `TwoFactorConfirmContext/context.tsx:75` non-null-asserts `twoFactorConfig!`. Needs a new field or non-2FA users get prompted/crashed.

**Also unguarded (arguably bigger):** `TeamMembers::ImportExistingVehicleTeamMembers` (`import_existing_vehicle_team_members.rb:16-39`) purges + grants ROLES in the same wizard step; also `upsert_fund_team_member.rb:29`, `remove_fund_team_member.rb:13`. `approver_count: 2` is worthless if you can add yourself as approver #2 with no step-up.

**Test gap:** PR adds only `delete_transfer_request_config_spec.rb`; zero specs exist for the import/purge settings mutations.

**STATUS 2026-09-14:** Kevin POSTED review #5201442519 (CHANGES_REQUESTED) from his account covering all four points + the CI note. CI: `test-angellist-1` red on build 138510 — judged a flake (neighbours green, no spec statically tied to diff, base a week stale); needs rebase + rerun. Devin claimed "Buildkite: 32/32 green" in its verification comment — FALSE, it never read Buildkite. Sharding is Knapsack Pro QUEUE mode (`bin/ci/test:36-42,72-78`) so shard number never identifies a file. No Buildkite API token on this machine (1Password "Buildkite" item is a LOGIN password only). Related: [[kevin-prefers-concise-ops-replies]].

**UPDATE 2026-09-14 18:42 — Devin accepted the review and split the PR.** New head `95404ca` (force-pushed, rebased onto same-day main; CI re-ran as build 140475). `95404ca` is exactly 2 deletions — the guard lines off `Settings::ImportExistingVehicleTransferRequestConfigs` and `Settings::PurgePrevImportedVehicleConfig`. PR is now 5 files, ZERO frontend: shared helper + `delete_transfer_request_config.rb:13` + the two sibling refactors + the delete spec. Split is safe — `deleteTransferRequestConfig` has exactly one FE caller, `Security/UpsertModal/index.tsx:105-132`, which pre-empts via `getValidTwoFactor()` at :110. Description corrected (false "FE already handles :unauthorized" claim removed; NOTE block now names all three deferred mutations + the missing `isMandatory` field).

**OPEN RISK:** body still says `Fixes SEC-829` and NO follow-up ticket exists (only SEC-829 is referenced anywhere in the PR). Merging auto-closes the pentest ticket while the wizard import/purge + `TeamMembers::ImportExistingVehicleTeamMembers` stay unguarded — exactly what the pentest report warned against. Recommended to Kevin: make Devin file the follow-up issue and downgrade `Fixes SEC-829` to a plain link. Kevin's review is still CHANGES_REQUESTED (blocking).

Chaos testing ([[chaos-testing-devin-playbooks]]) does NOT apply to this PR — backend-only, permanently. It applies to the follow-up FE PR.
