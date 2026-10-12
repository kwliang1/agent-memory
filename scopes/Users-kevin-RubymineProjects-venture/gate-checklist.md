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
- rubocop on the changed files.
- `srb tc`, plus `bin/tapioca dsl --verify` when scopes, enums, associations or columns change.

Related: [[feedback_gate_in_fresh_session]], [[venture-read-agents-md-best-practices]].
