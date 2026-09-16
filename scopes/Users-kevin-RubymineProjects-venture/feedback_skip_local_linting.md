---
name: Skip local linting, let CI handle it
description: Don't run type-checking or linting locally before creating PRs — just create the PR and let CI catch issues
type: feedback
originSessionId: 23384dd6-8451-4295-8e26-e1ffcfbfe214
---
Don't run `tsc --noEmit` or other linting/type-checking commands locally before creating PRs. Just create the PR and let CI handle validation.

**Why:** Local type-checking in this repo is slow and blocks progress. CI will catch the same issues.

**How to apply:** After making code changes, go straight to committing and creating the PR. Skip any local lint/typecheck steps.
