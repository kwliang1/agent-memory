---
name: bank1604-book-transfer-reversal
description: BANK-1604 — book-transfer-only maintenance task reversing erroneous completed BookTransfer
metadata: 
  node_type: memory
  type: project
  originSessionId: 173e7844-4435-4a58-b777-8e386e5f7db2
---

**BANK-1604** ("FBO Investors in QP-AT-1216 Fund I, a series of MV Funds, LP"; parent BANK-1603; project Balance Checks Improvements). Branch `kevinliang/bank-1604`, based on `origin/main`.

**Root cause (prod-verified via al console):** LedgerEntry 3896595 (LP_MOVEMENT, 270186→271537, $2,500) + its reversal 3896774 ("Undo double proration", rev_of 3896595) **net to zero** on the ledger; both ledger-only. In 2023 the reversal spawned a V1 BookTransfer (#161814, 264510→264408) that correctly **errored**. On 2025-09-02 someone retried it → **BookTransfer #681946** (tp `book_11mbexsj66p097q`, `state=completed`) which physically moved $2,500 264510→264408 with no net-ledger justification. The Linear issue mislabeled it "(stuck)" — it's actually completed-but-erroneous.

**The task** (`app/tasks/maintenance/book_transfer_sub_account264408_to264510_task.rb`, + spec, PR #8193): FINAL approach (Kevin redirected mid-review) = settle the missing bank leg of **LedgerEntry 3429958** (the canonical 2022 LP move CA 270186→271537 $2,500, `revised_amount_cents`=$2,500, confirmed in fund accounting, but booked ledger-only with NO BookTransfer). Uses `TreasuryPrime::BookTransfers::CreateService.create!(..., ledger_entry: LedgerEntry.find(3429958))` — assigns the EXISTING entry to a new BookTransfer (264408→264510) and submits the TP `book` call. Creates NO new LedgerEntry (verified: create!/submit!/complete! have no LedgerEntry-creating callback; completion is via TP webhook, emits no NATS event). This gives 3429958 its physical settlement + an auditable BookTransfer instead of a ghost transfer. 264408/264510 are the current active TP subs of CA 270186/271537 (the old 191135/194403 subs were migrated away). Guards: idempotency (refuse if 3429958 has any BookTransfer — console-safe, unlike the earlier MaintenanceTasks::Run guard); **sub-account/ledger-entry invariant** (264408/264510 must be 3429958's origin/dest active_sub_account — self-protecting against mismapping); TP-backed+external-id, active dest, can_book_transfer?, live source-balance canary. 14 specs. NOTE: the earlier "reverse #681946 recordless (no records)" approach was replaced — same physical movement, better framing (records + native idempotency). The `dusk` PR #8189 raw-recordless pattern is NOT what shipped here.

**Status (2026-07-10): SHIPPED — PR #8193** (signed, pushed, awaiting merge/run). 11/11 specs, sorbet clean, 2 review rounds (R2 clean). Kevin runs it via `/maintenance_tasks` UI.

**Signing note:** `op-ssh-sign` (1Password) produces unsigned commits (`gpg: N`) until Kevin authorizes 1Password interactively; once he did ("try again"), the amend produced a real `gpgsig` SSH header (verify via `git cat-file commit HEAD | grep gpgsig`, NOT `%G?` which shows N locally due to missing allowedSignersFile). See [[worktree-dev-auth]].

**Premise CONFIRMED via write console** (Kevin ran it — my session lacks `GlobalConsoleWriters` role, and read console can't reach TP balances → "not an HTTP URI"): SA#264408 (CA 270186) = **$2,500.06** (the misplaced cash), SA#264510 (CA 271537) = $9,800.63. Guard passes.

**Broader drift flagged (out of scope, candidate ticket under BANK-1603):** both wound-down FBO accounts have $0.00 *computed ledger* balance but nonzero *bank* balances ($2,500.06 and $9,800.63) — residual bank-vs-ledger drift beyond the $2,500 this task reverses.

**Design rationale (Kevin asked "why not undo the revision ledger entry?"):** the ledger pair (3896595+3896774) is already correct at net-zero; LedgerEntries are immutable so "undoing" means a new entry that either re-introduces the bogus double-proration OR launders the erroneous bank move into the books — both wrong. Only the physical bank position is broken (real client money in the wrong fund's FBO account), so the fix must be bank-only.