---
name: inc-5785-errored-short-adjust-bt-retry-not-cancel
description: Errored BT on a wire short-adjust (OW → GA14 settlement) — fund the GHB sub with a cash-only Transfer and retry the BT; don't cancel it. A V2 Transfer can't target a GlobalAccount.
metadata:
  type: project
---

An international wire's small short adjustment writes two LEs: CA → OW (active sub → the OW's GHB sub) and OW → settlement GA (the GHB sub → settlement), the second being a BookTransfer. If the GHB sub is inactive and holds $0, the BT errors.

- The CA → OW leg is ledger-only by design. OutgoingWire isn't in `CLASS_NAMES_WITH_SUB_ACCOUNT` (`transfers/create_service.rb`), so the cash is expected to already sit in `ow.sub_account`.
- Don't cancel the BT and create a Transfer instead. No V2 Transfer can land in a GlobalAccount: `sub_accounts_compatibility` (`transfer.rb:847`) requires CustomerAccount subs, and prod has 0 Transfers with a GlobalAccount origin or destination. A v1 CrossTransfer writes its own LE when it completes, so it would double-book.
- Fix: a cash-only V2 Transfer active SA → GHB sub (FUNDS_MIGRATION + USER_OVERRIDE, `ledger_entry:` the existing CA → OW LE), then `BookTransfers::CreateService.retry!(bt)`, which keeps the existing BT LE and links through `retried_book_transfer_id`. 0 new LEs. The read console rejects even rolled-back inserts (MySQL `--read-only`), so a dry run there only validates in memory.
- Race: balance-check auto-heal (`balance_checks/resolution_service.rb`) sweeps any positive TP balance from an inactive SA at :05 past 0/8/16 UTC. The BT retry cron runs at :00.

Recipe source: [[ach-pull-cross-ca-sub-landing]]. Related: [[treasury-ghb-fx-reroute]], [[intl-settlement-short-adjust-ct-never-completes]].
