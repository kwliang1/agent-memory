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

**Fix-verifier runs mutants, so it is a file-editing agent (2026-10-15):** launching it in the
branch worktree concurrently with the round's read-only reviewers made a reviewer see the mutated
file (` M app/models/transfer.rb` with the clause negated) and fall back to `git show <sha>:`. Run the
verifier before the round, or give it its own worktree / a `git worktree add --detach` copy.

**From a worktree, tapioca and packwerk also need the container (2026-10-15):** on the host both die on
`Missing Active Record encryption credential`. Run `bin/tapioca dsl --verify` and `bin/packwerk check` via
`docker compose -f docker-compose.yml -f docker-compose.worktree.yml exec -T app sh -c "..."`. And zsh does not
word-split `$SPECS` in `exec ... rspec $SPECS`: rspec gets one path with spaces and reports "0 examples, 1 error
outside of examples". Pass the list inside `sh -c "bundle exec rspec $SPECS"` instead.
