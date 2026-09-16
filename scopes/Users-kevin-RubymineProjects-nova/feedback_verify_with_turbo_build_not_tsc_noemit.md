---
name: feedback-verify-with-turbo-build-not-tsc-noemit
description: "Before pushing, verify types with the real `turbo build`, not just `tsc --noEmit` — they diverge and CI runs the former"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cb150723-8a16-47fc-9f46-a1010134e6e4
  modified: 2026-08-27T22:00:54.750Z
---

`pnpm exec tsc --noEmit -p tsconfig.json` in a package can pass while the production `turbo build` (which runs `tsc` to emit) FAILS on the same code. CI's buildkite runs `turbo build`. I pushed a mapper change that was clean under `tsc --noEmit` + unit tests + biome, but `turbo build` failed (exit 2) and regressed CI.

**Why they diverge:** stale local `packages/*/dist` and stale local `node_modules` deps. In one case a stale `@angellist/nova-vulcan-schema` had an `EntityType` union that still included a value CI's fresh build had dropped, so the local noEmit accepted an invalid literal the real build rejected. (See also [[feedback_stale_turbo_cache]].)

**Why:** the pre-push review gate exists to catch exactly these CI-shape failures; I skipped it on a "small" mapper change and shipped a red build.

**How to apply:** for any change that could affect types, run `pnpm turbo build --filter=<pkg> --force` (the CI command) before pushing — not just `tsc --noEmit`. And run the pre-push review gate even on small changes. To read a buildkite failure without a token, ask the user to paste the failing step (the builds are auth-gated).
