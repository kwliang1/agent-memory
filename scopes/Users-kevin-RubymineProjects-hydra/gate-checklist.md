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
- `env -u CHAT_PLATFORM DISCORD_BOT_TOKEN=test-token DEFAULT_SESSION_CHANNEL=000000000000000000 bun run test --isolate`, the exact CI env.
  A hydra-spawned shell inherits `CHAT_PLATFORM=slack`, which fails main-session tests that expect `discord-byte` (green in CI)
  (`.github/workflows/ci.yml` Run tests step). Without `DEFAULT_SESSION_CHANNEL` a test of a "no operator channel" path
  passes locally and fails in CI; `config.ts` exports it as a const-like `let`, so a test cannot unset it.
  Bare `bun test` is refused by `test-setup.ts`.

**Traps to brief reviewers on:**
- Credentials leaking into tmux command lines, Slack or logs. Hydra #357 found six separate leak paths.
- Hermetic git: `GIT_CEILING_DIRECTORIES` escaped 15 rounds and a human caught it.

Related: [[feedback_gate_in_fresh_session]].
