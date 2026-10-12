---
name: gate-checklist
description: Pre-gate CI-parity checks for hydra — run once before review round 1 and paste the results into every reviewer brief
metadata:
  type: reference
---

Read by step 0 of the pre-push gate in CLAUDE.md. Run each check once, then paste the results into
every reviewer brief so reviewers don't re-run them.

- `bunx tsc --noEmit`. It is CI's only type gate (`.github/workflows/ci.yml:35`), because bun's bundler
  erases types. Hydra #357 never ran it locally and CI went red after 24 rounds.
- `sh scripts/test.sh`, which runs bun test against a private tmux server. Bare `bun test` is refused by
  `test-setup.ts`.

**Traps to brief reviewers on:**
- Credentials leaking into tmux command lines, Slack or logs. Hydra #357 found six separate leak paths.
- Hermetic git: `GIT_CEILING_DIRECTORIES` escaped 15 rounds and a human caught it.

Related: [[feedback_gate_in_fresh_session]].
