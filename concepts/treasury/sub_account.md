<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, sub_account]
related:
  - [treasury, treasury_prime]
  - [treasury, customer_account]
  - [treasury, outgoing_payment]
---
symbols:  SubAccount, SubAccount::MigrationAccount, SubAccount::MigrationBatch, SubAccount::MigrationBatchConfig, SubAccounts::BalanceService, SubAccounts::CacheService, SubAccounts::CreateService, SubAccounts::CreateService::DuplicateSubAccountError, SubAccounts::InfoService, SubAccounts::InfoService::ProgramMigrationOption, SubAccounts::MigrationBatch::CreateService, SubAccounts::MigrationBatch::StateService, SubAccounts::MigrationBatchConfig::CreateService, SubAccounts::MigrationBatchConfig::InfoService, SubAccounts::Statements::UploadService, SubAccounts::UpdateService, SubAccounts::WireInstructions::FetchService, SubAccounts::WireInstructions::GenerationService, SubAccounts::WireInstructions::InfoService, SubAccounts::WireInstructions::InfoService::WireInstruction, SubAccounts::WireInstructions::InfoService::WireInstructions
files:    app/models/sub_account.rb, app/models/sub_account/migration_account.rb, app/models/sub_account/migration_batch.rb, app/models/sub_account/migration_batch_config.rb, app/services/sub_accounts/balance_service.rb, app/services/sub_accounts/cache_service.rb, app/services/sub_accounts/create_service.rb, app/services/sub_accounts/info_service.rb, app/services/sub_accounts/migration_batch/create_service.rb, app/services/sub_accounts/migration_batch/state_service.rb, app/services/sub_accounts/migration_batch_config/create_service.rb, app/services/sub_accounts/migration_batch_config/info_service.rb, app/services/sub_accounts/statements/upload_service.rb, app/services/sub_accounts/update_service.rb, app/services/sub_accounts/wire_instructions/fetch_service.rb, app/services/sub_accounts/wire_instructions/generation_service.rb, app/services/sub_accounts/wire_instructions/info_service.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
An IVC's CCA, IVA, escrow and disbursement accounts resolve to the CCA's single sub-account
(`SubAccounts::InfoService.customer_account_with_sub_account`), so a per-CustomerAccount loop
hits the same bank account up to 4 times. GHB omnibus sub-accounts share one full account
number across customer accounts. `account_number` is deterministically encrypted
(`sub_account.rb:64`): no SQL `LIKE` on it, so compare last-4s in Ruby.
provenance: BANK-2234 review gate, 2026-10-06
