---
name: reading-role-specs-concurrent
description: "Treasury resolvers using ApplicationRecord.connected_to(role: :reading) need specs tagged :concurrent — the reading connection can't see transaction-wrapped fixtures."
metadata: 
  node_type: memory
  type: project
  originSessionId: 2afc91b1-876e-43b5-83b5-9515dd636d3d
---

`ApplicationRecord.connected_to(role: :reading)` (e.g. `QueryResolvers::BalanceCheck::RunsResolver`) uses a separate connection pool, so FactoryBot data created inside DatabaseCleaner's default `:transaction` strategy is invisible to it — specs get empty results with no error.

**How to apply:** tag the spec `:concurrent` (`RSpec.describe Foo, :concurrent`) — `spec/support/database_cleaner.rb` switches that tag to truncation cleaning, committing fixtures so the reading connection sees them. Also materialize query results inside the `connected_to` block (`.to_a` / `.pluck`), or the lazy relation executes on the writer connection outside it.
