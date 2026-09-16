---
name: datadog-monitor-needs-unconditional-gauge
description: A Datadog monitor on a gauge only emitted while unhealthy fires once and never recovers — notify_no_data:false holds last state; default_zero() does NOT rescue a fully absent series
metadata: 
  node_type: memory
  type: reference
  originSessionId: c67a5b3d-00b1-4116-beed-4623b62190d4
  modified: 2026-09-15T17:08:01.324Z
---

**Never build a Datadog monitor on a metric series that only exists while something is wrong.** With `notify_no_data: false` the monitor holds its last evaluated state when the series disappears, so it alerts on breach and then sits in Alert forever — re-paging on `renotify_interval` until a human resolves it by hand. `default_zero()` does not save you: it fills gaps *inside* a series that has at least one point in the window, not a series that is entirely absent.

Concrete trap in treasury (hit on BANK-2089, caught by the review gate before merge): `Payments::Health::MonitorActivity#emit_active_gauges` tags `payment.health.<source>.<concern_type>` with `lifecycle_segment`, `payment_type`, `processor`, `level` — but `emit_zero_baselines` (`lib/temporal/activities/payments/health/monitor_activity.rb`) emits its zeros with only `payment_source`, `concern_type`, `level`, `env`, `kube_namespace`. So any monitor filtering on `lifecycle_segment:` (or payment_type/processor) never recovers.

**The house pattern instead:** emit an unconditional gauge and alert on a threshold over it. `emit_queued_gauges(relation, metric_prefix)` emits `<prefix>.count` + `<prefix>.max_age_minutes` unconditionally (0 when the relation is empty); monitors `sub-account-request-pending-verification.json` and `transfer-stuck-in-queued.json` both use this shape. Two further details that make it work:
- Emit **at the top** of the activity, before anything that can raise, so `notify_no_data: true` is a genuine liveness signal rather than a second failure mode.
- Datadog requires `thresholds.critical` to equal the query's literal (`> 7200` pairs with `"critical": 7200`).

**Also:** don't add a `warning` threshold that notifies the same handle as `critical` — it silently reinstates the page the higher critical threshold was chosen to avoid.

**And check the live population before merging any new threshold monitor** (`Transfer.queued.minimum(:created_at)` etc. via `al console exec -p -a treasury`). If a known backlog already exceeds the threshold the monitor is red on arrival; that's a merge-ordering fact to state, not something to code around with a filter.

Related: [[bank2089-inactive-sa-forward-stall]], [[datadog-docs-ci-owns-sync]]
