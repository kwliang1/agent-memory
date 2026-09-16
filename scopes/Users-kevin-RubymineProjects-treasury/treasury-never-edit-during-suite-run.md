---
name: treasury-never-edit-during-suite-run
description: "A treasury full-suite rspec run is not interruptible: editing files mid-run OR killing the run both produce scattered fake failures in unrelated specs. Reset the test DB after any interrupted run."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1a88ecdb-da63-4f54-b22e-a372bec5eacc
  modified: 2026-07-31T06:55:00.989Z
---

Never edit `app/` or `spec/` files while a background `bundle exec rspec` (full suite) is running in the treasury container. Rails autoloads during the run, so mid-run edits produce **scattered failures in specs unrelated to the change** — e.g. `ach_pulls/state_service_spec`, `tasks/maintenance/*`, `customer_accounts/system_accounts/info_service_spec`.

**Why:** a 12-14 minute full suite is tempting to overlap with review-agent turnaround. Did exactly that on BANK-1595: launched the suite, then applied review fixes while it ran, and got 6 failures in code I hadn't touched. Almost mistook it for a real regression.

**How to apply:** either wait for the run to finish before editing, or accept that the run is throwaway and re-run after edits land. When a full-suite run shows failures in files outside the diff, check whether anything was edited during the window **before** investigating the failures as real. Read-only review agents are safe to run concurrently; only writes are the problem.

## Killing a run corrupts the shared test schema

Same lesson, worse failure mode. `spec/lib/concerns/application_wide/permanent_spec.rb` **creates and drops a real table** (`permanent_spec_models` — visible as `drop_table(:permanent_spec_models, {if_exists: true})` in its output). Kill the suite mid-flight and that cleanup never runs, leaving the test schema polluted, so later runs fail in scattered unrelated specs.

**Signature that it's environmental, not your diff:** failure count *varies across runs on a fixed `--seed`*, and every named spec passes in isolation. A deterministic code change cannot do that. (Same signature as [[treasury-spec-tasks-maintenance-flake]].) On BANK-1595 this looked like 1 → 5 → 34 failures across successive runs.

**Recovery:** `docker compose -f docker-compose.yml -f docker-compose.worktree.yml exec -T -e RAILS_ENV=test app bundle exec rake db:drop db:create db:schema:load`, then re-run. Do this after *any* interrupted or killed suite run before trusting the next result — and check for it before spending time on "control" runs against `origin/main`.

Related: [[bash-cwd-persists-across-calls]] (the other way a run silently produces a false result), [[treasury-worktree-dev-loop]].
