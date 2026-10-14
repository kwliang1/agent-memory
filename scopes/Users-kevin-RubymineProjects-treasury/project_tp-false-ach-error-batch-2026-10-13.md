---
name: project_tp-false-ach-error-batch-2026-10-13
description: "47 Grasshopper ACH pushes ($281,517.45) falsely errored by TP webhooks at 09:00 UTC 2026-10-13; refunded to customers while bank debited; stuck errored, balance-mismatch surge; Harsohail owning repair"
metadata:
  type: project
  originSessionId: 67bbf956-b81d-4c6d-b6c6-6f690bf79dd9
---
2026-10-13 09:00 UTC: TP sent `ach.update` webhooks with status `error` for 47 Grasshopper (TP main instance) ACH pushes created Oct 7–9, total $281,517.45. Treasury ran `AchPushes::StateService.mark_as_errored!` on each: state → errored, refund LE AchPush → CustomerAccount, FAILED TreasuryEvent. TP re-sent webhooks at 14:43 UTC stamping `partner_bank_trace_number` on 46/47 and Thomas Ambrosia confirmed with TP that 132547 actually sent (false error). `complete!` only transitions from submitted/processing, so TP's `sent` is a silent no-op from errored.

Ids: `AchPush.where(state: 'errored').where('updated_at > ?', Time.utc(2026,10,12))`. Outlier 132694 ($311.12) got no trace number — may be a real error. 132736 still `submitted`, unaffected.

Effect: 47 customer accounts overstated by push amount (refund booked, bank debited) — the balance-check surge Kevin flagged in #banking-cool-people.

Owner: Harsohail Brar in #ops-banking-eng (thread ts 1791912645.401879), JIT write console requested to re-trace at TP. No errored→completed path exists in code; repair per push = reverse refund LE, completion LE to EXTERNAL_OUTGOING_FUNDS, state completed, payment_metric.completed_at, COMPLETED TreasuryEvent.

**Why:** TP status can regress error→sent; treasury treats `error` as terminal and refunds immediately.
**How to apply:** before repairing any errored TP ACH push, fetch its TP status (write console only); check [[treasury-prod-console-access]].
