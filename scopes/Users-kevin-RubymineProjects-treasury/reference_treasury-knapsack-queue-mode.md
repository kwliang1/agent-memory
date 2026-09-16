---
name: reference_treasury-knapsack-queue-mode
description: "Treasury CI shards rspec via KnapsackPro Queue mode (dynamic) — adding examples reshuffles node co-location and can surface others' spec-isolation bugs"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5b79408f-71b9-4055-9195-d1fa814dc99d
  modified: 2026-07-27T21:06:54.742Z
---

Treasury's Buildkite rspec runs (`rspec-treasury-0..3`, `parallelism: 4` in `.buildkite/pipeline.rb`) shard via **KnapsackPro Queue mode** — `bin/ci/rspec` → `bundle exec rake knapsack_pro:queue:rspec`. This is **dynamic, timing-based** distribution: each node pulls the next batch from a shared queue as it finishes, running MANY spec files per node in ONE rspec process.

**Consequence:** which specs co-locate on a node is non-deterministic and shifts run-to-run and whenever the total example set changes. **Adding/removing examples in ANY file can relocate OTHER files' co-location**, surfacing latent spec-isolation bugs (a spec that only passes when it runs first/clean, or that reads via the reading-role and needs committed data). A red shard whose failures are entirely in a spec you didn't touch is usually this — not your code. Confirm zero coupling (grep the failing spec for your changed classes/methods), then recommend a **shard rebuild** (queue redistributes) before assuming your change caused it.

Two gotchas hit while debugging CI from a worktree:
- `op signin` run by the user via `! op signin` does NOT carry into the Bash-tool shell (separate process) — `op whoami` still shows signed-out there. Can't use `op` for Buildkite tokens from tool calls; ask the user to paste the failed-examples list instead.
- Datadog CI Visibility (`search_datadog_test_events`/flaky-tests) has **no indexed rspec data** for treasury — dead end for "is this spec red on main" checks.
- A disrupted worktree DB (see [[feedback_mutation-agents-corrupt-worktree]]) can't faithfully run heavy full-graph specs (CrossTransfer/IncomingWire/Plaid) even after `db:drop db:create db:schema:load` — don't trust local repro of those failing; simple service specs still run fine.
