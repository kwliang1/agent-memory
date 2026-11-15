---
name: feedback-delta-only-gate-briefs
description: "After the early gate rounds, brief reviewers with the delta since the last clean round plus touched files, not the full diff"
metadata:
  node_type: memory
  type: feedback
  originSessionId: d078b82e-0bc9-4fa8-8301-7573db293bc9
  modified: 2026-11-09T21:28:38.886Z
---

From the later rounds of a long gate (once rounds 1-3 have covered the full diff), brief reviewers with only the delta since the last clean round plus the touched files, not the whole step diff.

**Why:** Kevin asked "why are the rounds taking so long?" (2026-11-09, BANK-2314 v2 step 5). Full 111KB briefs took 5-10 min per reviewer plus 10-15 min of fix/restack between rounds. He approved delta-only briefs ("yeah try it out").

**How to apply:** keep the prior-declines and CI sections; replace the full diff with the delta and the touched file:line ranges. Related: [[review-gate-playbook]].
