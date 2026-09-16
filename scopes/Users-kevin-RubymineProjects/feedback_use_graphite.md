---
name: Use Graphite for all git/PR operations
description: Always use gt (Graphite) commands instead of raw git/gh for branching, pushing, and PR creation
type: feedback
---

Always use Graphite (`gt`) for all branch/commit/push/PR operations — never raw `git push`, `git branch`, or `gh pr create`.

**Why:** User preference for consistent workflow. Graphite manages stacking, PR creation, and syncing.

**How to apply:**
- `gt create` to create branches (not `gt branch create` which is deprecated)
- `gt submit` to push and create/update PRs (not `git push` + `gh pr create`)
- `gt modify` to amend commits
- `gt sync` to sync with remote
