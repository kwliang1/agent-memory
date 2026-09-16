---
name: reference_ipseity_sentry_sql_breadcrumb_pii
description: "inlined values in raw SQL leak to Sentry's sql.active_record breadcrumb; use bind params for PII"
metadata: 
  node_type: memory
  type: reference
  originSessionId: b3595ab6-e83d-4c27-9b30-23fa6f1d5aae
  modified: 2026-08-20T05:05:40.060Z
---

ipseity's `config/initializers/sentry.rb` enables `:active_support_logger`, so sentry-rails captures a `sql.active_record` breadcrumb whose `data[:sql]` is the **full SQL text**. `before_send` filters it with `ActiveSupport::ParameterFilter`, which matches on **keys, not values** — the `sql` key isn't filtered, so any PII **inlined** into the SQL string (e.g. via `connection.quote(name)`) ships to Sentry on any captured event (a query timeout is the obvious trigger).

Fix / rule: pass PII as **bind parameters** (`exec_query(sql, "label", binds)` with `ActiveRecord::Relation::QueryAttribute`), never inlined — binds are excluded from the breadcrumb. This is why the blind-index/tax_id paths never inline TINs. Safe to inline only non-PII literals (e.g. an integer index via `.to_i`).

Also: the Prophet request-args logger (`log_subscriber`) runs args through `Rails.application.config.filter_parameters`, so PII wire keys must be added there too — use a **scoped compound key** (e.g. `'names.name'`) rather than a bare common key like `name`.

Broader corollary: `before_send` filters `extra/tags/user/contexts/breadcrumbs/request` but **not `event.exception`** (the exception messages + the whole `#cause` chain). So a generic re-raise that still carries the original error as `#cause` leaks the raw value — re-raise the generic error *outside* the `rescue` clause (nil-sentinel guard) so it has no cause. (`raise Err, msg, cause: nil` works in plain Ruby but Sorbet's `Kernel#raise` RBI rejects the `cause:` kwarg, so the out-of-rescue form is the Sorbet-safe fix.) `blind_index_concern.rb:254` documents the same gap (it uses `capture_message` with scrubbed text instead of `capture_exception`).

Related gotcha for batched raw-SQL text lookups: an embedded NUL is valid UTF-8 (so `String#scrub` keeps it) but illegal in a Postgres text bind — the pg driver raises `ArgumentError`. If many inputs share one batched query, that one bad cell fails the whole batch. Strip it (`.scrub.delete(0.chr)`) so a bad row degrades gracefully instead of taking out every other row.

Found while building NOVA-3883. See [[reference_ipseity_uuid_undashed]].
