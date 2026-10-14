---
name: nova-efa-vba-backfill-2026-10
description: 2026-10-14 EFA-without-VBA backfill — Aito BANK EFA blocked by a stray kl-distro-test VBA; the only two TREASURY EFAs hold MMF account ids and should not get VBAs; read console fails writes with Postgres 25006
metadata:
  type: project
---

Kevin asked (2026-10-14) for a prod script to give the only three VBA-less EntityFinancialAccounts a VirtualBankAccount.

- **Aito Capital Fund I LP BANK EFA `3c794b4a`**: its CA `2735305d…` was already on VBA `8c228130` under Kevin's `kl-distro-test` EFA `f8916a63` (3 VBAs, zero payment/transfer refs). Fix = delete the stray VBA and create a PRIMARY one on Aito's EFA, in one `$transaction`. Script in the jade thread (`D0BE3RB4Y00:1791961692.827019`).
- **The two TREASURY EFAs** (`avlok-kohli-money-market-fund-demo`, `aito-capital-fund-i-lp-treasury`) are the only TREASURY EFAs in prod. Their `treasuryAccountId` is an MMF account id (`lib/entity/financialAccounts.ts` passes it as `moneyMarketFundAccountId`), not a CustomerAccount, and every payout-VBA reader filters `accountType: BANK`. Recommended no VBA; Kevin had not decided as of this note.
- No code path creates TREASURY EFAs; all three VBA writers (`submitEntityKycForm`, `upsertFromVentureInvestmentEntity`, `executePort`) create BANK EFAs with `purpose: 'PRIMARY'` and a dash-stripped CA id.

**Trap:** `data.entity.virtualBankAccount.upsert` keys on the unique `treasuryCustomerAccountId`, so it silently re-points an existing VBA to a new EFA. For backfills use `create` after checking the CA is unclaimed.

**Trap:** Kevin's default `NOVA-GRAPH:PRODUCTION` REPL is the read console: a write inside `$transaction` fails with Postgres `25006 cannot execute DELETE in a read-only transaction` and nothing lands. Writes need `just console -p -w` (JIT `console-writers`). See [[reference_nova_graph_prod_console_query]].

**Update later 2026-10-14:** kl-distro-test EFA `f8916a63` has a second stray VBA `faf843cc` pointing at Aito's *treasury* EFA account `62a4cdb8…` (zero refs). Its real PRIMARY VBA `99a8d2b3` has 4 `transfersAsRecipient`, and Transfer→VBA is `onDelete: Restrict`, so the EFA/entity cannot be deleted without removing ledger rows; recommended leaving it. Final script (delete both strays + create Aito PRIMARY VBA in one `$transaction`) posted in the thread; Kevin runs it after getting JIT `console-writers` the morning of 2026-10-15.

**Done 2026-10-14 (afternoon):** Kevin ran the script in the write console: `deleted stray VBAs: 2`, Aito PRIMARY VBA `5e72f90b-1028-4258-b95c-a1d3fa7aed50` created. Remaining VBA-less EFAs are the two TREASURY ones, by design.

**Correction (same day, page check):** a TREASURY EFA *does* need a VBA. `pendingTransfers` → `getPendingWithdrawalTransfers` → `findByTreasuryCustomerAccountId` uses `findFirstOrThrow` (`graph/src/lib/entity/financialAccounts.ts:430`); with no VBA it throws, the field returns null, and the account page shows "Processing transfers couldn't be loaded". Seen on `portal.angellist.com/aito.vc/accounts/aito-capital-fund-i-lp-treasury`. Recommended creating the two TREASURY VBAs (script in thread) plus an optional `isTreasury()` skip in that resolver. Lesson: "no reader uses it" needs a grep of every lookup path, not just the BANK-filtered ones.

**Resolver fix PR:** angellist/nova#10980 (`kevinliang/treasury-efa-pending-transfers`, worktree `.worktrees/efa-treasury`): `pendingTransfers` early-returns `[]` for TREASURY EFAs. Gate: R1 two fixes (bank-branch test; early return instead of ternary because `getPendingTransfers` is entity-scoped), R2/R3 clean. Declined as follow-up: `ledger`/`ledgerPage`/`processingBalance` share the VBA-lookup root cause. Worktree traps hit: init'd from stale local main (reset to origin/main, `pnpm install` again), no `_test` DB (create empty + `prisma migrate deploy`; `migrate reset` refuses to run from Claude Code), stale proto/test codegen (`just codegen --filter=graph`), graph test paths must be `src/`-relative.
