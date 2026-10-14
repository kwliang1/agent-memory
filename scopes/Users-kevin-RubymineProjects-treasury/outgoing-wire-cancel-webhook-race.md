---
name: outgoing-wire-cancel-webhook-race
description: "Duplicate cancellation refund LEs on outgoing wires — OutgoingWires::StateService.cancel! has no row lock and races the TP wire.update webhook it triggers itself"
metadata:
  node_type: memory
  type: project
---

Confirmed 2026-09-21 on **OW 136010** ($50,000, CA 461874 "FBO Investors in Benjamin Bryant Demo Day
Fund S26: IV"). Second known occurrence; the first was **OW 131915** ($8,999,998.05, CA 459655
"FBO Investors in Antares", 2026-07-09). Sweep of `LedgerEntry` where `origin_type='OutgoingWire'`,
`category='DEPOSIT'`, `description LIKE 'Cancelled Wire%'`, grouped having count > 1 → those two only,
all-time. Cross-check detector: two `CANCELLED` `TreasuryEvent` rows for the same `subject_id`
(treasury_events retained back to 2025-12-15).

**Mechanism — we race a webhook we caused.** `TreasuryPrime::OutgoingWires::StateService.cancel!`
(`app/services/treasury_prime/outgoing_wires/state_service.rb:176-189`) PATCHes TP to `canceled`,
then calls `OutgoingWires::StateService.cancel!`. The PATCH makes TP fire `wire.update`, which lands
on a *different* web pod and runs `find_and_update_status!` → `OutgoingWires::StateService.cancel!`.

`OutgoingWires::StateService.cancel!` (`app/services/outgoing_wires/state_service.rb:295`) is the only
method in that service using a bare `ActiveRecord::Base.transaction` with **no** `outgoing_wire.with_lock`
— siblings at lines 23, 111, 123, 145, 164, 179, 191, 216, 228, 240, 252, 530, 752 all lock.
So: `can_cancel?` reads stale in-memory state; `return_to_customer_upon_cancellation!` sees the other
transaction's refund LE as uncommitted and so `balance` is still positive; both create the
`OutgoingWire → CustomerAccount` DEPOSIT; `outgoing_wire.cancel!` validates against the stale in-memory
attribute so the second transition doesn't raise. Result: the CA is credited twice, wire balance goes
negative, balance check fails. `complete!` (348), `reject!` (376) and `mark_as_treasury_prime_errored!`
(264) share the missing lock but are only reached *through* `find_and_update_status!`, which does hold
`with_lock` — `cancel!` is uniquely exposed because line 188 calls it outside any lock.

**Evidence (136010):** `TreasuryEvent` 1422193 @20:06:43.936194 and 1422194 @20:06:43.992587, both
`CANCELLED`, 56 ms apart. APM trace `4d00bb2a70af060ff5739a6d1b6bd5e6` = `OutgoingWireCancelMutation`,
956 ms, pod `web-…-9gzd6`, 20:06:43.24→44.23. Exactly one `TreasuryPrime::WebhookEvent` (id 11790203,
`wire.update`, 20:06:43) logged on pod `web-…-c42lg`, trace `54784d05…` (not in APM — sampling
priority 0). Both requests emitted the same triple of outbox enqueues 150 ms apart.
131915 matches exactly: one webhook 20:27:50, CANCELLED events @20:27:51.404 / .482.

**Fix:** wrap the mutation in `outgoing_wire.with_lock` and re-evaluate `can_cancel?` after the reload
— `cancelled` is not a from-state of the `cancel` transition (`app/models/outgoing_wire.rb:396`), so the
loser bails. Keep the TP HTTP calls outside the lock. Nested `with_lock` from the webhook path is safe
(same transaction re-acquiring the same row).

**Remediation precedent is inconsistent:** 131915 was repaired 2026-07-13 with a compensating
`Undo duplicate cancellation` LE 5739398; 136010 Kevin hard-`destroy`ed LE 5871540 on 2026-09-21.
Both leave a duplicate `CANCELLED` TreasuryEvent already published downstream (Prophet/NOVA) — assumed
idempotent, unverified. Related: [[duplicate-wire-debit-mismatch]], [[treasury-prod-console-access]],
[[feedback-repair-data-not-invariants]].

Status (2026-10-14, checked with gh): #8987 merged 2026-10-09 locks the wire row before cancelling. The index line called this unfixed, which was stale.
