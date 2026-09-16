---
name: reference_ipseity_entity_table_sizes
description: ipseity prod row counts (entities + identity_data_*) and how to pull them via al console
metadata: 
  node_type: memory
  type: reference
  originSessionId: b3595ab6-e83d-4c27-9b30-23fa6f1d5aae
  modified: 2026-08-21T00:43:14.167Z
---

ipseity prod row counts as of 2026-08 (planner estimates) — order of magnitude is the durable part:
- `entities` ~620k
- `identity_data_people` ~288k (largest detail table)
- `identity_data_companies` ~173k
- `identity_data_trusts` ~14k
- `identity_data_iras` ~4k
- `identity_data_unknowns` ~0.6k

These are **hundred-thousands, not millions** — the deciding fact for index choices. For NOVA-3883's trgm name search this meant **GIN, not GiST** (GiST's KNN only pays off at millions-of-rows scale with common-token floods). Flood proxy: the most common exact first+last name = ~1,598 people.

Pull prod counts read-only via `al console`:
`al console create -p -a ipseity --no-attach` then
`al console exec -p -a ipseity -- bundle exec rails runner "..."` then
`al console delete -p -a ipseity`.
Console namespace is `ipseity-ro`, read-only by default. Use pg_class `reltuples` for instant estimates. NOTE: pg_trgm is NOT installed on prod (only via the NOVA-3883 migration), so `similarity()` can't run there until it deploys.
