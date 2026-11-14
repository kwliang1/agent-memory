---
name: feedback_multi_pr_plan_in_each_pr
description: "For a change split across several PRs, every PR description carries the full numbered plan and marks which step it is"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 14c90216-1862-4483-b117-9b82ef48b917
  modified: 2026-11-06T07:07:56.276Z
---

When work ships as a series of PRs (dual-write → backfill → read switch → stop writes → drop column), put the whole numbered plan in **every** PR description, link the Linear issue, and mark the PR's own step ("This PR is step N of M", bold the step, "← this PR"). Include the merge/run gate on each step ("merge only after step 2 reports 0").

**Why:** Kevin asked for it on BANK-1807 (2026-11-06, #9516/#9518) after the plan grew from 3 to 5 steps. A reviewer opening any one PR should see where it sits and what it waits on.

**How to apply:** add the plan block at the top of the auto-generated section when opening each PR, and update every open PR in the series when the plan changes. Related: [[feedback_post_plan_to_linear]].
