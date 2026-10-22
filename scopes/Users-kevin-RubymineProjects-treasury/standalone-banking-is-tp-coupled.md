---
name: standalone-banking-is-tp-coupled
description: Standalone banking (create_operating_account) can't move off TP GHB Main by swapping the opener — three features are TP-only; Kevin kept it on TP 2026-10-21
metadata:
  type: project
---

`StandaloneBanking::OperatingAccountService.create_operating_account_ghb!` (venture fund, GP and ManCo standalone onboarding) hardcodes TP GHB Main and bypasses `SubAccountRequests::RoutingService`, so routing changes (e.g. ManCo → Increase GHB) never reach it.

Swapping it to DIBS Increase GHB breaks standalone banking (verified 2026-10-21 in a review gate on a dropped branch):
- `Api::StandaloneBankingsController#create_transfer` raises unless both accounts share a partner bank program, so mixed GHB Main / Increase firms can't book-transfer.
- `ExternalVaultAccounts::TransferService` submits the Plaid pull via `TreasuryPrime::CrossTransfers::CreateService` (no TP account on a DIBS sub; orphans the CrossTransfer).
- `StandaloneBanking::TransactionService#incoming_wire_info_as_proto` fetches wire detail from TP by `treasury_prime_wire_id`.
- Increase FBO opens park until KYC verifies; venture requests identity checks only after create_operating_account.

**Why:** code comment calls standalone banking "deprecated in favor of Nova"; Kevin chose to leave it on TP rather than port the three features.
**How to apply:** "move all ManCos to Increase" means the MANAGEMENT_COMPANY route only; don't re-propose the standalone swap without scoping the port. Related: [[treasury-ca-subaccount-provisioning-gotchas]].
