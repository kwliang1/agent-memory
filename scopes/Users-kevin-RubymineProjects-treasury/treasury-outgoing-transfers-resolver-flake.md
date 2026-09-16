---
name: treasury-outgoing-transfers-resolver-flake
description: "Known order-dependent flaky treasury spec: OutgoingTransfersResolver CA-scoped test; bare source_id collides across wire/payment tables"
metadata: 
  node_type: memory
  type: reference
  originSessionId: efbf16a9-1291-492d-bd66-682b2f8fd832
  modified: 2026-07-29T03:04:39.620Z
---

Treasury `spec/graphql/query_resolvers/outgoing_transfers_resolver_spec.rb:50` — `QueryResolvers::OutgoingTransfersResolver#resolve CA-scoped mode returns only records belonging to the specified customer account` — is a KNOWN order-dependent flake (seen 2026-07-28 on an unrelated PR's `rspec-treasury-3` shard; `main` was green).

Root cause: it asserts on bare numeric `source_id`s that are NOT namespaced by source type — `expect(source_ids).to_not include(_ow2.id.to_s, _op2.id.to_s)`. `OutgoingWire` and `OutgoingPayment` are separate tables with independent autoincrement ids, so an in-scope wire and an out-of-scope payment can share the same numeric id under an unlucky Knapsack ordering → false failure like `expected ["7", "6"] not to include "7"`.

If you see THIS spec red on a shard for a diff that doesn't touch the resolver / outgoing wires+payments, it's the flake, not your change — **retry the shard to confirm** (it passes on the same commit). Real fix shipped as PR #8391 (branch `kevinliang/fix-outgoing-transfers-resolver-flake`): assert on the resolver's namespaced `Entry#id` (`"ow-<id>"`/`"op-<id>"`/`"ap-<id>"`, unique across source types) instead of bare `source_id` — matching what the file's rail-filter examples already do. Verified 10× under random ordering. Getting a red treasury CI shard's failing example when Buildkite has no local token: drive Kevin's authenticated browser via Claude-in-Chrome to the Buildkite job URL and `get_page_text` (treasury rspec does NOT index to Datadog Test Optimization). See [[treasury-worktree-dev-loop]].
