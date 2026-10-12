<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, review_reason]
related:
  - [treasury, fraud_prevention]
  - [treasury, ach_push]
  - [treasury, user]
---
symbols:  ReviewReason
files:    app/models/review_reason.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
Nova compliance-review alerting is per movement: a payment with several review reasons counts as cleared only when all are cleared. It needs two alerts, SLA breach and treasury-vs-Flowdash state divergence, scoped to Nova money movements. See [[bank-1858-flowdash-divergence-monitor]].
src: -Users-kevin-RubymineProjects/2cc959b9-7b6d-4c0f-bc9c-486641c0ae8d.jsonl 2026-08-21T05:38:14Z "if a payment has multiple reasons, I just want to know when all review reasons have been cleared"
src: -Users-kevin-RubymineProjects/2cc959b9-7b6d-4c0f-bc9c-486641c0ae8d.jsonl 2026-08-22T01:24:48Z "the alert should also be triggered for DB and fd state divergence"
src: -Users-kevin-RubymineProjects/2cc959b9-7b6d-4c0f-bc9c-486641c0ae8d.jsonl 2026-08-23T22:58:59Z "This should only be fore nova money movements"
