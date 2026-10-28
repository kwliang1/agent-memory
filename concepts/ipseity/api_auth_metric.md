<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [ipseity, api_auth_metric]
---
symbols:  ApiAuthMetrics, ApiAuthMetrics::Outcome
files:    lib/api_auth_metrics.rb
indexed:  3d8de9038bbe812df55253c6f34357c67e53da57
<!-- end machine-owned -->

## Judgment
`outcome:env_secret` at zero is not enough to remove `ENTITY_API_SECRET`, despite the comment in `lib/api_auth_metrics.rb`: `config/initializers/entity_api.rb` raises at boot when it's blank and uses it as the client secret. Change the initializer first.
src: https://github.com/angellist/ipseity/pull/1684 2026-10-14T19:02:59Z "I am managing the cutover so will keep this in mind" (harsohailB)

REST auth also runs on the read-only `web-ro` pods, so any write in the auth path raises `PG::ReadOnlySqlTransaction` there. That review objection was dismissed and broke the next day. `ApiKey.touch_last_used!` is best-effort and skips on a read-only error, so `last_used_at` under-reports `web-ro` traffic.
src: https://github.com/angellist/ipseity/pull/1684 2026-10-14T19:02:42Z "We don't have any read only apps connected via API" (harsohailB)
