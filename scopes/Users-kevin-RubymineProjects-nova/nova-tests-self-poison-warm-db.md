---
name: nova-tests-self-poison-warm-db
description: "Several nova graph suites write hardcoded values into UNIQUE columns and never clean up, so they pass once and fail on every later run against the same test DB."
metadata: 
  node_type: memory
  type: project
  originSessionId: 5e731655-c52c-483b-8eea-11b3578a4e54
  modified: 2026-09-09T04:13:36.720Z
---

**FSM registration race (diagnosed 2026-09-08, sessions bloom+fern):** running multiple FSM-heavy graph suites in ONE vitest invocation can die at setup with `Unique constraint failed on the fields: (namespace,name)` from `packages/fsm/src/stores/prisma.ts:191` — `registerGraph` is find-then-create with no upsert/P2002 rescue (`stores/prisma.ts:170-195`), so two files registering the same graph concurrently race. It's a flake, not a real failure: suites pass alone. Also hits CI (nova build 48770). fern owns the standalone fix PR (P2002 rescue or upsert). Until it lands: re-run the failed file alone before believing it.

Some `graph` test files seed **hardcoded values into UNIQUE columns** and don't clean up. They pass on a fresh DB and fail on every subsequent run against the same one — CI never sees it (fresh DB per build), so it only ever bites local iteration.

Confirmed instances (2026-08-27, full-suite run: 542/545 files passed, all 3 failures were this):

- `src/routers/internal/usvc/transaction.test.ts` — writes `al_ipseity_entity_id = '00000000-0000-0000-0000-000000000099'`
- `src/internal/schema/templates/actions/update.test.ts` — handle `'Pantera-Opportunities-SPC-USTE'`
- `src/lib/dataroom/sync/dealAccessLinks/create.test.ts` — duplicate `dataRoomAccessLink.handle`

**Symptom:** `Unique constraint failed on the fields: (...)` in a file your change never touched, often at suite *setup* (so it reads as "3 files failed, 1 test failed").

**Do not** conclude your change broke them, and do not chase a red CI build with this. Clear the specific row (`update entity set al_ipseity_entity_id = null where ... = '…099'`) or recreate the test DB:
`psql "$POSTGRES_URL" -c 'DROP DATABASE nova_<name>_test'` + `CREATE DATABASE` + `POSTGRES_URL="${POSTGRES_URL}_test" pnpm -C packages/prisma exec prisma migrate deploy`.

This cost four separate false diagnoses in one session, including one where a genuinely red CI build was nearly attributed to it. Related: [[spawned-nova-worktree-is-bare]] (the other big local-environment red herring).

**Also from that session:** when a Buildkite build fails and `gh` shows no annotation (Buildkite 403s unauthenticated fetches), eliminate what you *can* run locally — repo-wide `biome check`, `tsc` in `graph` **and** `app`, both codegens, `packages/prisma build`, the full `pnpm -C graph test` — then re-push an amend with byte-identical content. The pipeline (`.buildkite/pipeline.rb`) documents retries for OOM (exit 134) and spot-reclaim, so a one-off red is a real failure mode. That is what it turned out to be.
