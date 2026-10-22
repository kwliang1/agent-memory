---
name: gate-checklist
description: Pre-gate CI-parity checks for venture — run once before review round 1 and paste the results into every reviewer brief
metadata:
  type: reference
---

Read by step 0 of the pre-push gate in CLAUDE.md. Run each check once, then paste the results into
every reviewer brief so reviewers don't re-run them.

- Specs with `MOCK_ENTITY_API` off (see [[mock-env-vars-differ-by-repo]]).
- `bin/packwerk check`. On bank-2230 the tests/CI lens ran rubocop and srb but never packwerk,
  and CI went red after two clean rounds. See [[feedback_venture-packwerk-boundaries]].
- `git diff --name-only origin/main...HEAD | grep '\.rb$' | xargs bin/ci/rubocop_changed_files.sh` — CI's exact check. Plain `rubocop <files>` buries the one error-level offense under hundreds of pre-existing conventions; on bank-2321 a `%w[]` (Style/WordArray, error level here) went red in CI that way. Pipe through xargs: zsh doesn't word-split `$F`, and the script then prints "No changed Ruby files to lint" and passes.
- `srb tc`, plus `bin/tapioca dsl --verify` (CI's `bin/ci/ensure_sorbet_in_sync`) when scopes, enums, associations, columns change, or a new GraphQL type is added: every `*::Types::BaseObject` subclass gets a DSL RBI, and bank-2341 missed one after a "srb tc clean" gate.

Related: [[feedback_gate_in_fresh_session]], [[venture-read-agents-md-best-practices]].
