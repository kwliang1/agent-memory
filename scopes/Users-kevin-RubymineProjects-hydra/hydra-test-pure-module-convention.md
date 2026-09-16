---
name: hydra-test-pure-module-convention
description: "hydra testing — daemon/config.ts and dashboard.ts aren't test-importable; put pure logic in dependency-free modules"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0db8a201-6d0d-4a6c-9e96-f994eac450ab
  modified: 2026-07-22T22:56:26.806Z
---

In the **hydra** repo (`~/RubymineProjects/hydra`, Bun/TS chat bridge), `daemon/config.ts` calls `process.exit(1)` at import if Slack/Discord tokens aren't set and constructs a live gateway; `daemon/dashboard.ts` has a module-scope `setInterval`. So **any module importing them is NOT `bun test`-importable.**

Convention (see `daemon/__tests__/pr-watch.test.ts`): extract testable logic into a **pure module with no config/gateway/registry imports**, import that directly in tests. Example added 2026-07-22: `daemon/artifacts.ts` (extract/render/merge for Home dashboard link lines) is pure; `dashboard.ts` and `bridge-dispatch.ts` consume it.

Also: compile-check all three entry points before committing — `bun build {daemon.ts, cli/hydra.ts, bridge.ts} --target bun` — they're independent module graphs (per hydra CLAUDE.md). A recurring pre-existing full-suite flake: 2 `peek_session` failures in `orchestration-tools.test.ts` from test-ordering pollution (pass in isolation) — not caused by your diff.

Build protocol routing: builder→critic review posts lead with `[builder→critic]`; the closing summary (after critic LGTM) leads with `[summary]`. Untagged posts are conversational (to the human). A liveness ping expecting `[builder→critic]` can fire as a stale-cadence race right after a valid `[summary]` — don't repost as builder→critic, it restarts the review loop.
