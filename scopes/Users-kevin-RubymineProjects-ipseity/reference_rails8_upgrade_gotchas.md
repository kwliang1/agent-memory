---
name: rails8-upgrade-gotchas
description: "Concrete breakages hit upgrading an AngelList Rails app 7.1→8.1 (ipseity BANK-1846), reusable for treasury/other repos"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 2e75f0f0-fa64-4a79-9860-e372426381a1
  modified: 2026-09-09T16:47:30.377Z
---

Verified upgrading ipseity 7.1.3 → 8.1.3.1 (PR #1556). Reusable for the treasury sibling (BANK-1845) and other AngelList Rails-8 upgrades. Order roughly by when they bite.

**Bundler blockers (gate resolution):**
- `prophet` git gem pinned `railties ~> 7.1` → bump ref to `8c94a09` (see [[prophet-rails8-ref]]).
- `flipper-active_record 0.28.x` caps `activerecord < 8` → `flipper ~> 1.3`. Read path (`Flipper.enabled?`) is stable across the major.

**Rails 8.0 removals (crash on boot/eager-load):**
- `ActiveSupport::ProxyObject` removed → inline `BasicObject` (`undef_method :==`/`:equal?` + a `raise` shim for exact parity).
- kwarg `enum foo: {...}` → positional `enum :foo, {...}`.
- multi-action route shorthand `put :a, :b` → two separate `put` calls (raises `wrong number of arguments (expect 1..2)` at route-draw time, cascading `UrlGenerationError` across many controller specs).
- singular `config.fixture_path=` → plural `config.fixture_paths=[...]`.

**7.2 behavior changes:**
- `config/secrets.yml` no longer read → prod must set `SECRET_KEY_BASE` env (Rails reads it natively; verify in configtool). Delete the file.
- ActiveJob eagerly assigns the configured adapter to request specs → jobs run inline mid-request (hit real integrations). Add a `queue_adapter_for_test` override included into `type: :request`.
- PG uuids get *cast* (not just deserialized) → a dashless-uuid app needs `cast_value` override too, not just `deserialize`.

**Gem cascade (install but need bumps):**
- `puma ~> 6.4.2` pin strands it; puma 6.4's rack handler calls `Rackup::Handler.register` which rackup 1.x lacks → Capybara integration specs blow up. Bump `puma ~> 6.6`.
- `paper_trail` → 17 (17 adds 8.1, zero breaking changes; 16 caps AR <8.1). PT16+ rejects a 2nd `has_paper_trail` → use `paper_trail.setup(...)`.
- `factory_bot_rails < 6.5` breaks on 8.1 (`ActiveSupport::Delegation::Inflector`); `shoulda-matchers 4.x` → 6.x; `rspec-rails` → 7.x; `database_cleaner-active_record` → 2.2.
- `connection_pool`: drop the `< 3` pin (resolves to 2.5.5 conservatively, or floats to 3.x; both work on 8.1 — Rails #56292 fixed the c-pool-3/fiber incompat). ⚠️ unit suite runs threads/puma, NOT `isolation_level = :fiber` under falcon — load-test the fiber path before prod.
- `rails_semantic_logger 4.17` is broken on 8.1: calls `ActiveRecord::RuntimeRegistry.sql_runtime` (removed in 8.1) → rescued ("Could not log") so specs stay green, but it spams errors and **drops SQL logging in prod**. Bump to **4.20** (the `remove_const :INTERNAL_PARAMS` monkeypatch still works; 5.x needs semantic_logger 5, blocked by prophet's `~> 4.0`).

**Sorbet/tapioca (this is the CI blocker, budget real time):** CI gate = `bin/ci/ensure_sorbet_in_sync` (srb tc + `tapioca gems --verify` + `tapioca dsl --verify`).
- Pin **`zeitwerk < 2.7`** (NOT `< 2.8`): the `Zeitwerk::Registry::Loaders` API that tapioca 0.16 can't introspect landed in **2.7**. Rails 8.1 only needs `~> 2.6`.
- **DSL RBIs must be regenerated for 8.1** — this is the real `dsl --verify` failure, easy to miss. 8.1 drops `sorbet/rbi/dsl/active_record/normalization.rbi` + `validations.rbi`, and can no longer generate the `verifier` through-association on the Accreditation models (~140 DSL files change).
- **tapioca `dsl` CRASHES on macOS host** (parallel workers → `Marshal.load: EOFError`; `--workers 1` is non-idempotent). It works fine in **linux** (CI proves it). Regenerate in an isolated linux container: `docker compose -p <name> run -d --no-deps -e SSH_AUTH_SOCK=/agent.sock app sleep infinity` (fresh bundle volume so the main 7.1 bundle is untouched; shares the fixed-name `ipseity` network to reach `db_pg`; SSH agent forwarded for private git gems), then exec `bin/tapioca gems --no-loc --no-doc` + `RAILS_ENV=development bin/rails db:create db:schema:load` + `bin/tapioca dsl`. RBIs land in the mounted worktree.
- After regen, `srb tc` may flag `ActiveSupport::ForkTracker::ModernCoreExt` in nats-pure/connection_pool RBIs (AS 8.1 renamed it `CoreExt`) → force-regen those gems (`bin/tapioca gem nats-pure connection_pool`). `FFI::ModernForkTracking` needs a shim in `sorbet/rbi/shims/ffi.rbi`.
- Related: [[ipseity_specs]], [[ci_ssh_only_git_gems]].

**Reliability (the green suite can't see these):**
- A hand-rolled PG **auto-reconnect monkeypatch that prepends `exec_query`** becomes a SILENT NO-OP on 8.1 — live queries route through `internal_exec_query`/`internal_execute`, not `exec_query`. Effect: failover reconnect/backoff stops firing; `StatementInvalid` propagates to consumers during RDS failover instead of self-healing. Re-target the patch to `internal_execute` (guard against double-retry vs 8.1's built-in `with_raw_connection` retry) and validate with a staging failover drill (`pg_terminate_backend` + RDS reboot). Treasury likely has the same patch.
- Prod runs falcon + `isolation_level = :fiber`; the suite runs puma/threads → the fiber + connection_pool path is unexercised. RDS IAM auth (SharedVentureTooling shim patching the connect path) is env-gated off in CI. Boot-time `SECRET_KEY_BASE` (after deleting secrets.yml) only matters in prod configtool. Roll out ipseity FIRST + alone (it's the producer), canary + watch pool saturation/p99/ConnectionBad.

**Strategy that worked:** keep `load_defaults 5.2`, add fully-commented `new_framework_defaults_7_2/_8_0/_8_1.rb`, flip nothing. Reuse the Rails 7.2 PR #1518 (Thibaut) fixes when going straight to 8.1. For the huge diff, **stack** code (PR A) under the regenerated RBIs (PR B) — but note PR A's `sorbet-check` is red by design (its RBIs are in PR B); merge the stack bottom-up. Shipped as ipseity #1556 (code) ← #1570 (codegen).
