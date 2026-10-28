---
name: ipseity-entity-api-commit-compiled
description: Changes under ipseity's entity_api/ must be committed compiled, and parallel version bumps conflict in four files
metadata:
  type: reference
---

`bin/ci/release_entity_api` runs `rake compile` in `entity_api/` and fails on any resulting diff ("Please run 'make api-compile', update entity_api/version.rb and commit the changes"). So run `make api-compile` and commit its output with every proto or gem change.

Two PRs that both bump the gem collide on `entity_api/lib/entity_api/version.rb`, the CHANGELOG and both `Gemfile.lock` files. On rebase, keep the higher version and both CHANGELOG entries, then recompile.

Related: [[ipseity-consumer-pin-to-branch]].
