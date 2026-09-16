---
name: treasury-point-in-time-balances-created-at
description: "Treasury as-of balances filter on created_at and there is no effective-date column, so a late correction never reconciles for a past close date."
metadata: 
  node_type: memory
  type: reference
  originSessionId: d6cf4061-a283-45c5-88e1-858304d907b5
  modified: 2026-09-09T04:27:37.414Z
---

`Accounts::BalanceService.cash_balance!` DOES take `as_of` (and `up_to_ledger_id`; passing both
raises). `as_of` filters `scope.where('created_at <= ?', as_of)` — `app/services/accounts/balance_service.rb:89-91`.

**`ledger_entries` has only `created_at` / `updated_at`. There is no effective/posted/booked date
column.** So the ledger cannot express "booked in September, belongs to May", which is exactly what a
late correction needs. A repair entry written today never reconciles an as-of date before today —
the audit gap stays fully present at every prior close date.

Hit on the 2026-08-28 audit-vs-revised RCA: #8724's repair entries were written 2026-09-01, so
Accounting's 6/30 close still showed the gap. Affected the two deposits that predate 6/30
(Etherscan 2026-01-27 $1,012,500; Paytrack 2026-05-25 $3,980,827 = $4,993,327); Etched.ai
(2026-08-17) post-dates it.

**`created_at` is NOT in `LedgerEntry::READONLY_ATTRS`** (that list is id, uuid, requester_type/id,
origin_type/id, destination_type/id, amount_cents, forced_by_user_id — `ledger_entry.rb:125`), so
backdating is technically possible. Two positions, decision is Kevin's (put to him 2026-09-08):
- Against: destroys the booked-at record on an unrewritable ledger; silently shifts created_at-windowed
  artifacts. Durable fix = `effective_at` column defaulting to `created_at`, `as_of` filtering on it.
- For (glyph, 2026-09-08): the 6/30–8/31 periods were still OPEN (adjusting entries into an open period
  are normal); `revised_only` excludes repair entries so customer balances provably can't move; booking
  time survives in updated_at + task run + PR. **PR #8809** (treasury, 4-round review-gate clean) is the
  ready-to-run `Maintenance::BackdateAuditGapRepairEntriesTask` for the seven repair entries
  (5836098–100, 5839103–06 → each revised entry's created_at). Consumers checked: venture cptr
  fund-accounting sync dedupes by uuid (post-run check in PR body); lib/reports.rb quarterly window
  unaffected; sub-account sums date-blind; no update callbacks/CDC on update_columns.

Interim answer for a close that's already blocked: close off the REVISED ledger (correct at the time
and still correct) and carry the audit side as a documented reconciling item.

Related: [[ikyam-incident-orphan-zeroings]], [[treasury-three-balance-functions]], [[ledger-recon-measure-every-account]]
