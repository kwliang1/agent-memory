---
name: new-model-checklist
description: "When adding a new model in venture -- migration, schema dump, schema cache, annotation, RBI"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 021ac3c2-b0c1-4819-a048-9574a5a80dda
---

When creating a new ActiveRecord model in venture, commit ALL of these:
1. Migration file (`db/migrate_banking/` or `db/migrate/`)
2. Schema dump (`rails db:schema:dump:banking` or `db:schema:dump`) -- CI uses `schema:load`
3. Schema cache (`rake db:schema:cache:dump`) -- run migration on dev DB first, not just test
4. Model annotation -- `annotate` runs automatically after migration; verify the `== Schema Information` block
5. Gem RBIs (`tapioca gem <gem>`) if gem versions changed
6. DSL RBIs (`tapioca dsl ModelName`) for the new model

When DELETING a rake task, also remove its cron entry in `cdk8s/schedule.ts`.

CI checks that fail when these are missing:
- `schema-cache-angellist` -- stale schema cache
- `annotations-angellist` -- missing/stale model annotations
- All test shards -- table doesn't exist (schema:load uses schema file, not migrations)
