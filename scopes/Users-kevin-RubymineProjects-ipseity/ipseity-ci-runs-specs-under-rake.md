---
name: ipseity-ci-runs-specs-under-rake
description: ipseity CI runs rspec through rake, and the PaperTrail initializer branches on $0, so a spec can pass under plain rspec and fail in CI
metadata:
  type: reference
---

`bin/ci/test` runs `rake spec` (or `rake knapsack_pro:queue:rspec`), and `config/initializers/paper_trail.rb` sets `whodunnit` to `"rake …"` when `File.basename($0) == "rake"`. Under plain `bundle exec rspec` whodunnit stays unset. A spec that touches PaperTrail versions can pass locally and fail only in CI.

**How to apply:** when a spec fails only in CI, reproduce with CI's `$0`:

```sh
bundle exec ruby -e '$0="rake"; ARGV.replace(["spec/path_spec.rb"]); load Gem.bin_path("rspec-core", "rspec")'
```

Related: [[gate-checklist]].
