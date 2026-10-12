---
name: payment-activities-spec-order-flake
description: "CI-only stub-clobbering flakes (payment_activities state_service_spec et al.) come from rake loading sorbet-runtime before rspec-mocks, which skips sorbet's rspec compatibility patch; fix is PR #9049. Plain rspec can't reproduce it."
metadata:
  node_type: memory
  type: reference
  originSessionId: 06c3cfad-b7c9-4982-9adf-be4d80e734cd
  modified: 2026-10-05T23:12:26.466Z
---

**Root cause (2026-10-05, verified):** CI runs specs inside rake (`bin/ci/rspec` → `rake knapsack_pro:queue:rspec`). `Rakefile:6` loads the app, and with it sorbet-runtime, before rspec-mocks. sorbet-runtime's `lib/types/compatibility_patches.rb` installs its rspec-mocks patch only `if defined? ::RSpec::Mocks`, so CI never had it. Plain `rspec` loads rspec-mocks first (spec_helper `mock_with`), so local runs always did. Without the patch, a stub that uses `and_wrap_original`/`and_call_original` on a lazily sig'd method is overwritten on the first real call, when sorbet redefines the method on its owner. `payment_activities/state_service_spec.rb` (and `outgoing_wires/state_service_spec.rb:184`) failed ~30 examples whenever it ran first on a shard (main build 34756, PR build 34758).

**Fix:** PR #9049 (`kevinliang/payment-activities-state-spec-flake`), green on CI 2026-10-05, not yet merged. `spec/support/sorbet_rspec_compatibility.rb` re-`load`s the patch (`require` would no-op), plus a spec asserting it's installed.

**How to apply:**
- If a CI-only flake involves a stub on a sig'd method and #9049 isn't merged, retry the shard.
- To reproduce CI's load order locally, load the Rakefile and then call `RSpec::Core::Runner.run(ARGV)` in the same process. The `/flakey-spec` skill's plain `rspec --seed` loop will pass even without the fix.
- My first guesses were wrong: ID collision, then a one-method `T::Utils.signature_for_method` workaround. A gate reviewer found the load-order cause.
