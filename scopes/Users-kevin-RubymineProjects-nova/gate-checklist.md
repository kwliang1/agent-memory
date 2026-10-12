---
name: gate-checklist
description: Pre-gate CI-parity checks for nova — run once before review round 1 and paste the results into every reviewer brief
metadata:
  type: reference
---

Read by step 0 of the pre-push gate in CLAUDE.md. Run each check once, then paste the results into
every reviewer brief so reviewers don't re-run them.

- `NODE_OPTIONS=--max-old-space-size=12288 pnpm -C graph lint:types` — trust the **exit code**, not a
  grep. An out-of-memory crash (exit 134) has read as "0 errors" on BANK-2120, bank-1997 and BANK-2057.
  See [[feedback_verify_with_turbo_build_not_tsc_noemit]].
- `pnpm turbo build --filter=<pkg> --force` for every touched package (this is CI's build).
- Lint every touched package, including `packages/fsm` (bank-1997 skipped it).
- App tests through just/turbo: [[reference_app_tests_need_just_turbo]]. Mind
  [[turbo-caches-lint-and-test-results]].
- After any checkout between stacked branches: `pnpm -C graph schema:dump && pnpm -C app codegen`.

**Traps to brief reviewers on:**
- Prisma's 32,767 bind-parameter limit. Bank-1997 hit it twice, at G1 R1 and again at G5 R1.
- Cross-process and deploy concurrency: rolling deploys, lock guards. Cursor and Bugbot caught both
  after bank-1997 passed.

Related: [[feedback_gate_in_fresh_session]], [[review-gate-cache-cost-accounting]],
[[feedback-declined-finding-does-not-reset-gate]].
