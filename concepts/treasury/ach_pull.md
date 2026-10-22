<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, ach_pull]
related:
  - [treasury, treasury_prime]
  - [treasury, fraud_prevention]
  - [treasury, submittable_ach]
---
symbols:  AchPull, AchPull::State, AchPull::State::Enum, AchPulls::CreateService, AchPulls::StateService
files:    app/models/ach_pull.rb, app/models/ach_pull/state.rb, app/services/ach_pulls/create_service.rb, app/services/ach_pulls/state_service.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
Cancel through `AchPulls::StateService.cancel!`, not the model's `cancel!`. Only the service guards `can_cancel?`,
cancels at TP/DIBS, stamps `payment_metric.cancelled_at`, and emits the Cancelled state-change TreasuryEvent that
venture's consumer turns into `Investment::Payments::StateService.switch_to_wire!`. The `after_commit` hooks
(Flowdash task and PaymentActivities sync) fire either way, so a bare model `cancel!` looks fine locally and silently
skips venture. Known bare caller: `Plaid::MicrodepositVerifications::StateService.fail_microdeposit_verification!`.
provenance: BANK-2227 / treasury#9060 follow-up analysis, 2026-10-07
