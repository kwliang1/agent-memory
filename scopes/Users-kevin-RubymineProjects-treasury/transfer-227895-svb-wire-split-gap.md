---
name: transfer-227895-svb-wire-split-gap
description: "RCA Transfer 227895 stranded $2.03M SVB wire — PR #8126 ACH-split gap in the wire-reassignment (revise_ledger_entry_destination!) path"
metadata: 
  node_type: memory
  type: project
  originSessionId: fd12d489-212d-490d-bb2c-450f3fba6af3
  modified: 2026-08-20T18:57:58.599Z
---

Transfer **227895** ($2,033,164.98, DESTINATION_CHANGE, payment_type `wire`, SVB sub 146311→Grasshopper 262833) stuck in `queued` since 2026-08-12, funds stranded on SVB. Requester = IncomingWire **317969** (Sixty Degree Capital Fund IV, "SVB FOR BENEFIT OF AL ADVISORS"); wire landed on SVB sub of CA 220866 but destined for CA **220868**.

**Root cause:** same failure mode as CA 238959, but a path PR **#8126** (BANK-1572) never patched. #8126 added `forward_in_ach_chunks!` **only** inside `IncomingWires::StateService#forward_funds_to_active_sub_account!` (`state_service.rb:449`, called from the *else* branch `:121`). Wire 317969 hit the **sibling mismatch branch** `state_service.rb:69` (`original_sub_account.customer_account != original_to_account`) → `LedgerEntries::RevisionService.revise_ledger_entry_destination!` (`:82`). That method (`revision_service.rb:225`) creates ONE Transfer V2 for the full amount, no split. `Transfers::V2::CreateService#determine_payment_type!` (`create_service.rb:151-154`): SVB→GH, >$1M ⇒ Wire. SVB can't submit wires programmatically ⇒ `queued` forever. IncomingWire flips to `transferred` so it *looks* done.

**Blast radius:** swept prod `queued`+`payment_type=wire` → 227895 is the ONLY stranded case.

**Fix (real gap):** move the >$1M SVB→non-SVB ACH split to the movement layer (teach `revise_ledger_entry_destination!` or a shared helper both paths call), predicate `from.svb? && amount > MAX_ACH_AMOUNT && !to.svb?` (same as #8126). **Immediate unblock:** cancel 227895, recreate as **3** ACH chunks $1M + $1M + $33,164.98 SVB 146311→GH 262833 — needs Kevin's go + write console. NOTE >$2M ⇒ two identical $1M same-day chunks = the dup-detection/daily-ACH-limit case #8126 flagged (238959 at ~$1.14M dodged it as 2 distinct chunks); confirm w/ TP or stagger across days.

**Fix = BANK-1849 / treasury PR #8611** (OPEN, signed+verified, Buildkite running, NOT merged): split moved to movement layer in `revise_ledger_entry_destination!` (else-branch loops ACH chunks when `Transfers::InfoService.requires_svb_ach_split?`); shared `requires_svb_ach_split?`+`ach_split_amounts` in InfoService; forward path refactored to reuse them. 3-round review gate passed (round 2 caught a real spec bug: new revision contexts added a 2nd ACTIVE sub → single-active-sub validation; fixed by making the SVB sub CLOSED, mirrors incident). Safe because revision balances are derived not stored + revision LEs filtered wholesale from clean ledger/available_balance.

**Unblock script** for 227895 lives at scratchpad `unblock_227895.rb` (cancel queued wire → recreate 3 ACH DESTINATION_CHANGE chunks, dry-run default, idempotent, supports staggering via CHUNK_INDICES). NOT run — awaiting Kevin's go + write console + the >$2M TP dup-detection decision.

**>$2M dup-detection concern RESOLVED by prod precedent (2026-08-20):** 2026-06-01 SVB sub 505309→268652 had **3× identical $1M same-day ACH debit-pulls all completed** (Transfers 140083/84/85, FUNDS_MIGRATION/Debit/ach/init=TP/recv=SVB, random-UUID tokens = ad-hoc split). So 2 identical $1M same-day is safe → run 227895 unblock all 3 chunks same-day, NO staggering. Also: `forward_in_ach_chunks!` (#8126) has NEVER fired in prod (0 split-forward groups; 238959 fixed by ad-hoc script) → #8611 auto-split path still unexercised in prod.

Status 2026-08-20: **PR #8611 CI GREEN** (Buildkite #33101, all 4 rspec shards + brakeman/packwerk/sorbet-in-sync/Bugbot), signed+verified, MERGEABLE, blocked only on human review — NOT merged. First CI run was RED: both new revision specs failed "Origin has insufficient funds" (credit LE origin lp_account1 only $1k; `accounts_allow_transfer` enforces debit balance). Fixed by forcing the setup credit (`forced_by_user: create(:user), force_reason: USER_OVERRIDE, force_note: 'Test'` — how `:with_balance` factory funds). Reproduced+verified locally via worktree docker (`docker compose -f docker-compose.yml -f docker-compose.worktree.yml run --rm --no-deps -e RAILS_ENV=test app bundle exec rspec ...` after `make setup-worktree`): 47/0 (revision+info specs) + 56/0 (incoming_wires). LESSON: review agents can't run code → runtime fixture gaps slip past them; run specs. Unblock script ready but NOT run (awaiting Kevin go + write console). Console RBAC gotcha: after token expiry, `al auth login -p` alone didn't restore console — needed `al console create -a treasury -p --no-attach` to re-provision the treasury-ro pod.
