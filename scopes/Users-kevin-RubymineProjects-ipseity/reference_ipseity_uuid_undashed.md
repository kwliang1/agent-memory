---
name: reference_ipseity_uuid_undashed
description: ipseity stores/returns entity UUIDs un-dashed; raw-SQL uuid reads come back dashed and must be normalized
metadata: 
  node_type: memory
  type: reference
  originSessionId: b3595ab6-e83d-4c27-9b30-23fa6f1d5aae
  modified: 2026-08-20T04:36:00.379Z
---

ipseity's `config/initializers/uuid.rb` overrides the AR uuid cast to strip dashes, so `Entity#id` / `entity_api_id` is the un-dashed 32-char hex form (e.g. `e141d8a4e0344b64a45782373e5b94f2`) everywhere in the entity API.

But a **native `uuid` column read via raw `exec_query`/`select_all` bypasses that cast** and returns Postgres' canonical **dashed** form. So any raw-SQL path that returns an entity id must normalize with `value.to_s.delete('-')` to match what AR-loaded ids, `entities:show`, and `lookup_by_tax_id` return — otherwise nova's id join silently breaks.

Found while building NOVA-3883 (`Entities::NameLookupService`); caught by a spec asserting equality against `Entity#id`. See [[reference_ipseity_sentry_sql_breadcrumb_pii]].
