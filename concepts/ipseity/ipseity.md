<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [ipseity, ipseity]
related:
  - [ipseity, entity]
---
symbols:  Ipseity, Ipseity::Statsd, Ipseity::Uuid
files:    lib/ipseity/statsd.rb, lib/ipseity/uuid.rb
indexed:  3d8de9038bbe812df55253c6f34357c67e53da57
<!-- end machine-owned -->

## Judgment
UUIDs are dashless in-app, and the dashed form leaks at known edges that `spec/initializers/uuid_boundaries_spec.rb` pins. GoodJob's columns must stay dashed (`GoodJobUuid`): stripping them broke `retry_on`, perform limits and lock release, and lost events in prod. Keep ids another system mints out of the stripping `uuid` type. See [[reference_ipseity_uuid_undashed]].
src: https://github.com/angellist/ipseity/pull/1700 2026-10-24T00:04:55Z "`GoodJobUuid` overrides `strip_dashes?` so GoodJob uuids stay dashed" (dcetlin)
src: https://github.com/angellist/ipseity/pull/1707 2026-10-27T19:07:46Z "If a later change moves either boundary, one of these fails here instead of silently missing lookups." (dcetlin)
