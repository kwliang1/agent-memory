<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, plaid]
related:
  - [treasury, internal]
  - [treasury, external_ach_account]
  - [treasury, external_vault_account]
---
symbols:  Plaid, Plaid::AchAccountService, Plaid::ApiService, Plaid::BankConnection, Plaid::BankConnections::BalanceService, Plaid::BankConnections::IdentityService, Plaid::BankConnections::UpdateService, Plaid::BankTransferEventUpdate, Plaid::BankTransferEventUpdatePolicy, Plaid::BankTransferEventUpdateService, Plaid::Institutions::InfoService, Plaid::MicrodepositVerification, Plaid::MicrodepositVerification::VerificationType, Plaid::MicrodepositVerifications::CreateService, Plaid::MicrodepositVerifications::CreateService::PlaidAccountBlockedError, Plaid::MicrodepositVerifications::FetchService, Plaid::MicrodepositVerifications::InfoService, Plaid::MicrodepositVerifications::StateService, Plaid::MicrodepositVerifications::UpdateService, Plaid::TransactionEntry, Plaid::TransactionFetchService, Plaid::TransactionSyncService, Plaid::TransactionUpdate
files:    app/models/plaid.rb, app/models/plaid/bank_connection.rb, app/models/plaid/bank_transfer_event_update.rb, app/models/plaid/microdeposit_verification.rb, app/models/plaid/transaction_entry.rb, app/models/plaid/transaction_update.rb, app/policies/plaid/bank_transfer_event_update_policy.rb, app/services/plaid/ach_account_service.rb, app/services/plaid/api_service.rb, app/services/plaid/bank_connections/balance_service.rb, app/services/plaid/bank_connections/identity_service.rb, app/services/plaid/bank_connections/update_service.rb, app/services/plaid/bank_transfer_event_update_service.rb, app/services/plaid/institutions/info_service.rb, app/services/plaid/microdeposit_verifications/create_service.rb, app/services/plaid/microdeposit_verifications/fetch_service.rb, app/services/plaid/microdeposit_verifications/info_service.rb, app/services/plaid/microdeposit_verifications/state_service.rb, app/services/plaid/microdeposit_verifications/update_service.rb, app/services/plaid/transaction_fetch_service.rb, app/services/plaid/transaction_sync_service.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
A verification fails only from `pending`. While it is pending, its pulls can be `pending_microdeposit_verification`,
`cancelled`, `blocked` or `needs_admin_attention`, and only the first can take `cancel`. So
`fail_microdeposit_verification!` must filter `with_state(:pending_microdeposit_verification)`, as the verify path
does. Before #9060 it cancelled every pull. A raise there rolled back `mark_failed_verification!`, so the verification
stuck at `pending` and every retry 500'd again.
The cancel there is the bare model `cancel!`, not `AchPulls::StateService.cancel!`, so no Cancelled TreasuryEvent
reaches venture (`Treasury::EffectsService.ach_pull_cancelled` → `switch_to_wire!`). That is still open after #9060.
provenance: BANK-2227 / treasury#9060, 2026-10-07
