---
name: feedback_ci_bisect_verify_against_green
description: "Before blaming a commit for a CI regression, verify the \"offending\" code is absent from currently-green builds — a transient outage window fakes a deterministic bisect"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 706429f4-12e4-4fce-8fdb-5c893319e12c
  modified: 2026-08-19T22:31:04.144Z
---

When root-causing a red pipeline by bisect (parent build green, suspect build red), do NOT
conclude the suspect commit is the cause until you check whether **currently-passing builds still
contain the exact code you're blaming**. A transient CI/infra outage that spans several consecutive
builds looks identical to a deterministic code regression: green → red-wall → and the first red build
is just the first commit that happened to build during the outage.

**Why:** On nova (build-wt, e2e pipeline) I confidently blamed #9535's one-line Subscriptions drawer
href change via an airtight-looking bisect (parent #46834 green, #9535 #46836 red, red persisted
across #9543/#9476). It was wrong. The red band was builds #46835–#46842 (~74 min, ~20:32–21:46 UTC)
that **self-healed with the code unchanged** — current green HEAD still had the identical
`subscriptions.index({ tab: 'pipeline' })` line. It was a transient client-side hydration failure, not
the commit. I shipped a PR "fixing" a non-bug and had to walk it back.

**How to apply:**
1. Pull the recent execution history for the failing test (Buildkite Test Analytics → the test → "Recent
   test executions" bar + list): is it green → red-band → green? A red *band* that recovers with no
   relevant commit = environmental/transient, not code.
2. `git show <suspect>:<file>` on **current origin/main HEAD** — if the "offending" code is still
   present in a build that now passes, the commit is exonerated.
3. Distinguish server vs client failure from `init_container-app.log`: fast HTTP 200s spaced exactly at
   the Playwright test-timeout interval (e.g. ~122s) + blank page snapshots (aria = logos + toast only)
   = client-side hydration failure, NOT a backend outage (headless api/v1 specs stay green). Hermetic
   CI ships no RUM/APM to Datadog, so the exact JS error is only in the per-test `trace.zip` console
   (download-gated).

Related: [[feedback_stale_turbo_cache]] (a bad/stale turbo artifact is a documented nova footgun that
produces exactly this kind of transient, build-window-scoped, self-healing breakage).
