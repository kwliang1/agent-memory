<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, balance_check]
related:
  - [treasury, sub_account]
  - [treasury, treasury_prime]
  - [treasury, customer_account]
---
symbols:  BalanceCheck::Classification, BalanceCheck::Record, BalanceCheck::Record::InProgressDetail, BalanceCheck::SlaLevel, BalanceChecks::CheckService, BalanceChecks::DifferenceService, BalanceChecks::InsightsService, BalanceChecks::RecentlyActiveAccountsService, BalanceChecks::ResolutionService
files:    app/models/balance_check/classification.rb, app/models/balance_check/record.rb, app/models/balance_check/sla_level.rb, app/services/balance_checks/check_service.rb, app/services/balance_checks/difference_service.rb, app/services/balance_checks/insights_service.rb, app/services/balance_checks/recently_active_accounts_service.rb, app/services/balance_checks/resolution_service.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
Once a balance-check gap is confirmed against the bank, repair the data first (with Kevin's go-ahead for any prod write), then open the code PR.
src: -Users-kevin-RubymineProjects/31ca1194-49f4-46cd-a777-256bcb2c717b.jsonl 2026-09-29T23:24:55Z "repair first, then start on PR"
Diagnosis (the balance-check-diagnosis skill, treasury#9116) must include inactive sub-accounts and skip only terminated ones: filter `not_terminated`, not `closed_at: nil`. A TP API call bills that sub-account as active, so ask before live TP calls on inactive subs.
src: -Users-kevin-RubymineProjects/1d545ee6-6e42-43fb-b41e-a8d214cff6da.jsonl 2026-10-09T18:03:30Z "We should be looking at inactive subaccounts, but not ones that are terminated"
