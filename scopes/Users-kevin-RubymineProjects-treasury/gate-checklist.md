---
name: gate-checklist
description: Pre-gate CI-parity checks for treasury — run once before review round 1 and paste the results into every reviewer brief
metadata:
  type: reference
---

Read by step 0 of the pre-push gate in CLAUDE.md. Run each check once, then paste the results into
every reviewer brief so reviewers don't re-run them.

- Specs in the container with the mocks off: `docker compose exec -e RAILS_ENV=test app env -u MOCK_IPSEITY
  -u MOCK_ANGELLIST bundle exec rspec <changed specs>`. From a worktree, see
  [[treasury-specs-sibling-container]].
- `bin/ci/ensure_sorbet_in_sync`, which is srb plus `tapioca gems --verify` plus `tapioca dsl --verify`.
  `srb tc` alone misses the DSL RBIs: [[srb-tc-is-not-the-sorbet-ci-step]].
- `bin/packwerk check` ([[feedback_treasury-packwerk-dibs]]).
- `bin/ci/rubocop_changed_files.sh`.

**Traps to brief reviewers on:**
- MySQL's 64-character limit on advisory-lock names. BANK-2234 R6 would have been a prod outage.
- Any ledger, wire, ACH or MMF change gets a money-path lens. Long treasury gates (bank-2150,
  BANK-2234, no-EIN wires) were long because the money paths really had bugs.

Related: [[feedback_gate_in_fresh_session]].
