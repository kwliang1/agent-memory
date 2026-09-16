---
name: check-buildkite-ci
description: "CI green means Buildkite green — always verify via gh pr checks or Buildkite directly, listing each step"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 224aaeec-406e-4ba8-96ad-3fb4dc4bb467
---

"CI green" means **Buildkite green** — not GitHub status checks, not a pr-watch notification saying "CI Passed."

**Why:** Reported CI as "green" multiple times based on GitHub checks or pr-watch notifications alone while Buildkite had failures. Kevin called this out explicitly: "What is your definition of clear? I find you miss CI issues quite frequently."

**How to apply:** Before claiming CI is green or a PR is ready:
1. Run `gh pr checks <number>` and verify the `buildkite/treasury/pr` line says `pass`
2. Confirm each Buildkite step passed: `rspec-treasury-{0..3}`, `sorbet-treasury`, `brakeman-treasury`, `packwerk-treasury`, `ensure-server-in-sync`, `ensure-next-client-in-sync`, config-validate steps
3. Never trust a pr-watch "CI Passed" notification as the sole source — always verify directly
4. When reporting CI status to Kevin, list the specific Buildkite steps checked, not just "CI green"
