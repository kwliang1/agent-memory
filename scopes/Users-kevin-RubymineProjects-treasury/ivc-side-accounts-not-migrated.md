---
name: ivc-side-accounts-not-migrated
description: Which IVC side accounts (mirror, on-core, loan, vault, MMF) ever take part in a sub-account migration — Kevin's calls, verified 2026-11-11
metadata:
  type: project
---
Kevin (2026-11-11, BANK-2314 v2): only the CCA-shared set (CCA/IVA/disbursement/escrow) migrates. Mirror and vault are slated for deprecation, loan is not implemented, on-core accounts are never migrated, and MMF is its own bank account.

Verified in code: the TP webhook skips on-core (`treasury_primes_controller.rb:198`); `setup_loan_accounts_upon_approval` has no app caller in venture or nova; the GSIB vault is console-created with a stub, already-open Morgan Stanley sub account. But `MigrationService.migrate!` has no guard, so a manual migrate of a side account is possible.

**Why:** `migration_accounts` (via `for_customer_account`, 9 IVC columns) and `cca_sub_account_holders` (4 columns) disagree only for these side accounts. Kevin chose to leave that mismatch alone.

**How to apply:** don't raise the two helpers' divergence for side accounts as a bug. Re-raise it only if a flow starts migrating on-core, loan or MMF accounts.
