---
name: project-todo-incoming-wire-ledger-requested-entries
description: "TODO (2026-09-30) — treasury incoming-payment page's ledger tab hides the return leg because it only lists entries where the wire is origin/destination; show requested_ledger_entries too"
metadata:
  node_type: memory
  type: project
  originSessionId: b5e49ee1-6ed2-4ee7-8096-aa2221085908
  modified: 2026-09-30T22:30:50.392Z
---

Kevin asked for this as a local TODO on 2026-09-30 while tracing the Terran Robotics return (IW 297083 / 297383). Own treasury PR.

**Gap:** the incoming payment page renders `<AccountLedgerEntries accountType={IncomingWire}>` (`frontend/app/(authenticatedRoutes)/incoming_payments/[id]/page.tsx:581`), which lists entries where the wire is origin or destination (`Account#ledger`, `app/models/concerns/account.rb:71-77`). The return leg that `IncomingWires::StateService.return!` creates is booked CA → same CA between two sub-accounts, with the wire only as its *requester*. So LE 5750779 / 5750782 (T199654 / T199653) and the auto-forward's LE 5756397 / 5756398 never appear on the wire's page, only on the customer account's. It hid the whole incident, and it's the same query trap that misled a review agent into "no ledger skew".

**Fix:** also show the wire's `requested_ledger_entries` (the association already exists, `account.rb:51`), e.g. as a "Related entries" section or a toggle, labeled so it isn't confused with the wire's own balance-bearing entries.

**How to apply:** don't start until Kevin picks it up. Check the GraphQL resolver behind `AccountLedgerEntries` first; the frontend alone may not have a requester filter. Related: [[project_todo_transfers_table_svb_processor_flip]], [[project_terran-robotics-wire-omnibus-shortfall]].
