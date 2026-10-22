---
name: entity-api-bump-regenerates-two-gem-rbis-and-dsl
description: Bumping treasury's ipseity git pin changes TWO gem RBI filenames (entity_api and entity_prophet_api) and may need new DSL RBIs for added proto messages; CI's sorbet step verifies both
metadata:
  type: reference
---

Treasury's `Gemfile.lock` pins one ipseity git revision that ships two gems, `entity_api` and `entity_prophet_api`. Tapioca names gem RBIs `<gem>@<version>-<revision>.rbi`, so a pin bump invalidates both files even when only one gem changed. CI (`bin/ci/ensure_sorbet_in_sync`) runs `tapioca gems --verify` then `tapioca dsl --verify`; `srb tc` alone passes with a stale filename.

**Why:** a pin bump went red once on the `entity_prophet_api` filename and would have gone red again on missing DSL RBIs for proto messages added upstream (`EntityAPI::Messages::SimpleEntity{,Results}` from entity_api 0.44.0).

**How to apply:** after a pin bump run `make gem-rbis` (or `bin/tapioca gem entity_api entity_prophet_api --no-doc --no-loc`), then `bin/tapioca dsl --verify` in a container with a fresh suffixed dev DB (`TREASURY_DB_SUFFIX=_x rake db:create db:schema:load`; the shared dev DB usually has pending migrations) and `bin/tapioca dsl <NewMessage>` for anything it lists. Host `tapioca gem` also deletes `sorbet/rbi/gems/resolv@*.rbi`; restore it. Related: [[srb-tc-is-not-the-sorbet-ci-step]], [[treasury-specs-sibling-container]].
