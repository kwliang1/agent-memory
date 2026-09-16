---
name: rake-spec-double-load-tasks
description: Two rspec files each calling Rails.application.load_tasks makes every rake task body run twice — guard the load; treasury now has spec/support/rake_task_helper.rb
metadata: 
  node_type: memory
  type: reference
  originSessionId: f47c16b3-3921-4f56-973d-9f74cd90f794
  modified: 2026-07-29T06:35:42.644Z
---

`Rails.application.load_tasks` called from more than one spec file makes rake task bodies run **once per load**. `Rails::Engine#run_tasks_blocks` uses `load` (not `require`), so the second call re-executes every `.rake` file, and Rake **appends** to an existing task's action list rather than replacing it. `Rake::Task#invoke` then runs the body N times.

**Symptom:** a mock expectation like `expect(Svc).to receive(:foo).with(...)` fails with `expected: 1 time / received: 2 times`. It only fires when both spec files land in the same process, and only in one order — so it reads as an intermittent flake. Treasury's CI uses Knapsack **Queue** mode (dynamic file→worker assignment), so "both files on the same worker" is a coin flip per build.

**Why a single-file run hides it:** running just your own new spec passes (one action). I got 310 green examples and still shipped the bug into review; it took running `spec/tasks/` as a directory with a specific seed to surface it.

**Fix (landed on `kevinliang/bank-1544`, treasury):** `spec/support/rake_task_helper.rb` defines `load_rake_tasks_once` → `Rails.application.load_tasks if Rake::Task.tasks.empty?`, wired via `config.include`. `spec/rails_helper.rb:22` globs `spec/support/**/*.rb`, so it's auto-required. Both `spec/tasks/intrafi_spec.rb` and `spec/tasks/temporal_spec.rb` call it from a per-example `before` — which also resolves the `RSpec/BeforeAfterAll` rubocop offense honestly instead of tolerating it (that cop exists for exactly this: `before(:all)` state leaking past the example). Guarding only the new file does NOT work — whichever file loads second does the appending.

Also remember `task.reenable` in a `before` hook; rake tasks only run once per process otherwise.

Related: [[treasury-spec-tasks-maintenance-flake]], [[spec-neighborhood-must-include-tasks]], [[treasury-worktree-dev-loop]].
