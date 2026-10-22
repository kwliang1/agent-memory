---
name: inc-5785-errored-short-adjust-bt-retry-not-cancel
description: Errored BT on a wire short-adjust (OW → GA14 settlement) — fund the GHB sub with a cash-only Transfer and retry the BT; don't cancel it. A V2 Transfer can't target a GlobalAccount.
metadata:
  type: project
---

INC-5785, 2026-10-20. OW 138007's $0.01 short adjustment wrote LE 5941301 (CA → OW, 518425 FTB → 495715 GHB) and LE 5941302 (OW → GA14, 495715 → 166754, which is BT 796480). The BT errored because 495715 was inactive and held $0.

- The CA → OW leg is ledger-only by design. OutgoingWire isn't in `CLASS_NAMES_WITH_SUB_ACCOUNT` (`transfers/create_service.rb`), so the cash is expected to already sit in `ow.sub_account`.
- Kevin's first instinct was to cancel the BT and create a Transfer. But no V2 Transfer can land in a GlobalAccount: `sub_accounts_compatibility` (`transfer.rb:847`) requires CustomerAccount subs, and prod has 0 Transfers with a GlobalAccount origin or destination. A v1 CrossTransfer writes its own LE when it completes, so it would double-book.
- Fix I handed over: a cash-only V2 Transfer active SA → 495715 (FUNDS_MIGRATION + USER_OVERRIDE, `ledger_entry:` LE 5941301), then `BookTransfers::CreateService.retry!(bt)`, which keeps LE 5941302 and links through `retried_book_transfer_id`. 0 new LEs. Validated in memory on the read console only, because the read console rejects even rolled-back inserts (MySQL `--read-only`).
- Race: balance-check auto-heal (`balance_checks/resolution_service.rb`) sweeps any positive TP balance from an inactive SA at :05 past 0/8/16 UTC. The BT retry cron runs at :00.

Recipe source: [[ach-pull-cross-ca-sub-landing]]. Related: [[treasury-ghb-fx-reroute]], [[intl-settlement-short-adjust-ct-never-completes]].
