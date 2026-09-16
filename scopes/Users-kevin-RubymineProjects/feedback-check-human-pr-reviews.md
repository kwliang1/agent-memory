---
name: feedback-check-human-pr-reviews
description: "Before calling a PR done/ready-to-merge, fetch its human reviews directly — pr-watch pings are unreliable and miss some reviews"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: efbf16a9-1291-492d-bd66-682b2f8fd832
  modified: 2026-07-29T23:55:44.095Z
---

Before declaring a PR "ready to merge" / "done", explicitly fetch its human reviews and review comments — don't rely on pr-watch pings, which are unreliable and miss reviews.

**Why:** on #8389 (2026-07-29) I called it green + ready after my own automated reviewer rounds; a human reviewer (sf8193 / "Sam") had left an "Approve — but 3 changes before merge" review (make `error_code` abstract, rename `report_to_sentry?`→`report_to_error_tracker?`, trim the mixin header, + a TODO nit) that I never saw. pr-watch pinged for a DIFFERENT PR's approval (#8393) but not for this one, so I missed it and had to circle back when Kevin asked "did you address Sam's concerns?"

**How to apply:** whenever wrapping up / reporting a PR as ready, run
`gh api repos/{owner}/{repo}/pulls/{N}/reviews --jq '.[] | {user:.user.login, state, body}'`
and `.../pulls/{N}/comments` (inline) and `.../issues/{N}/comments`. Surface any human requested-changes/COMMENTED reviews and address them before saying "ready." My own review-agent rounds ([[review-loop-attribution-discipline]]) are not a substitute for reading the human reviews on the actual PR. See also [[pr-watch-phantom-pings]].
