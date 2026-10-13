---
name: srb-tc-is-not-the-sorbet-ci-step
description: "`srb tc` passing locally does NOT mean the sorbet CI step passes — it also runs `tapioca gems --verify` and `tapioca dsl --verify`; a new ActiveRecord scope reddens CI with a clean local typecheck"
metadata:
  type: reference
---

`bin/ci/ensure_sorbet_in_sync` — the `buildkite/treasury/pr/sorbet-treasury` step — runs **three**
checks, not one:

1. `bin/sorbet` (what `bundle exec srb tc` covers locally)
2. `bundle exec bin/tapioca gems --verify`
3. `bundle exec bin/tapioca dsl --verify`

On 2026-09-28 I pushed PR #9000 with `srb tc` clean and CI went red on (3). The cause: two new
`scope :pending_settlement` declarations on `OutgoingWire` and `AchPush`. Tapioca generates an RBI
stub per scope in `sorbet/rbi/dsl/<model>.rbi` (they already listed `def queued`, `def
not_submitted`, …), so the checked-in RBIs were stale. Nothing local warned me — the regenerated
diff was +6 lines per file.

**Anything that changes the generated DSL surface needs `tapioca dsl` before pushing:** a new
scope, an enum value, an association, a schema/column change. Cross-reference
[[treasury-enum-value-ci-and-rollback]], which is the same failure for enums.

**Regenerating from a worktree — two traps.**

`make rbi` is `$(COMPOSE) exec -t -i app bin/tapioca dsl`, and the `treasury` container binds
`/Users/kevin/RubymineProjects/treasury` — the **main checkout**. From a worktree it regenerates
against main's code, silently producing the wrong answer. Run tapioca host-side instead:

```sh
bundle exec bin/tapioca dsl OutgoingWire AchPush   # name the constants; full runs are slow
```

Tapioca loads the Rails app and aborts on pending migrations, checking the **development** DB
regardless of `RAILS_ENV`. Kevin's local dev DB runs behind main, so this usually fails. Do **not**
migrate his dev DB to get past it — `config/database.yml` reads `TREASURY_DB_SUFFIX`, so stand up a
throwaway and drop it after:

```sh
export RAILS_ENV=development TREASURY_DB_SUFFIX=_rbitmp
bundle exec rake db:create db:schema:load
bundle exec bin/tapioca dsl OutgoingWire AchPush
bundle exec rake db:drop
```

Verify the diff is only the new symbol before committing — a full `tapioca dsl` run will rewrite
unrelated files. Related: [[treasury-worktree-spec-env-quotes-and-rustfs]] for the env the above
needs, and [[gt-submit-dry-run-resets-shared-trunk]] for why touching shared dev state is worth
avoiding.
