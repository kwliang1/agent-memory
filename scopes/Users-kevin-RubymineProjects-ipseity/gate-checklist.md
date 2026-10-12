---
name: gate-checklist
description: Pre-gate CI-parity checks for ipseity — run once before review round 1 and paste the results into every reviewer brief
metadata:
  type: reference
---

Read by step 0 of the pre-push gate in CLAUDE.md. Run each check once, then paste the results into
every reviewer brief so reviewers don't re-run them.

- `bundle exec rspec <changed specs>` (ipseity *is* the entity API, so there's no mock to unset).
- `srb tc`. Check the `typed:` sigil on every new file: `typed: true` on a new service turned CI red
  on BANK-2156.
- rubocop on the changed files.

Related: [[feedback_gate_in_fresh_session]].
