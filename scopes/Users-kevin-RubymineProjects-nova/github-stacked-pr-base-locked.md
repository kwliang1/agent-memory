---
name: github-stacked-pr-base-locked
description: GitHub refuses to change the base of a PR that is part of a native stack (422 "part of a stack")
metadata:
  type: reference
---
`PATCH /repos/angellist/nova/pulls/<N>` with `base=` returns 422 "Cannot change the base branch because the pull request is part of a stack" once a PR sits in a GitHub-native stack (seen 2026-10-26 trying to put #11246 on a new bottom PR).

**How to apply:** decide the bottom of a stack BEFORE opening the PRs; to insert a new bottom later, plan on folding the change into the existing bottom PR or asking Kevin, not retargeting.
