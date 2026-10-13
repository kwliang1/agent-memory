---
name: tsc-filter-by-cause-not-by-path
description: "Classify every tsc error by cause, never grep the output down to your own file paths — a newly-required field on a shared type breaks files your diff never touches"
metadata:
  node_type: memory
  type: feedback
---

On nova #10269 I ran graph's `tsc` the way CI does, got 35 errors, grepped them down to
`^src/(data/account|services/entityMatchmaking)`, saw `0`, and told Kevin the type-check was clean.
It wasn't. `src/services/fsm/entityMatchmakingReplay.test.ts` — a file main added *after* my branch's
base, which my diff never touched — constructs a `PortablePlan`, and my change had made
`submittedEmail` a required field on that type. `lint-types-graph` would have failed CI. A review
agent found it; my own filter hid it.

**Why:** a widened type reaches every construction site in the program, and the ones that break are
by definition the ones you didn't edit. Filtering by your own paths inverts the search.

**How to apply:** after any `tsc` run you intend to report, classify *every* remaining error into a
named cause — stale codegen (`test/types/gen/graphql`), stale `packages/*/dist`, or real. Say the
count per class. If a class is "pre-existing", prove it (the symbol doesn't exist in your diff, or
it reproduces on the base). Never report a filtered-to-my-files zero.

Related: [[graph-tsc-ooms-and-reads-as-clean]], [[feedback-two-reviewers-per-round]].
