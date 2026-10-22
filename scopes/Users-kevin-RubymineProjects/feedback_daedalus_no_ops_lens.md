---
name: feedback-daedalus-no-ops-lens
description: Daedalus gate rounds skip the ops/blast-radius lens — it is a single-user internal tool
metadata:
  node_type: memory
  type: feedback
  originSessionId: a3aaea89-30d1-4a35-9d13-2b25c9a6735c
  modified: 2026-10-17T21:29:14.967Z
---

Don't pick an ops / deploy / concurrency lens for Daedalus gate reviewers. A CLI blast-radius lens is still wanted: bad args, an empty or old ledger, changed output or exit codes, runtime.

**Why:** Kevin, 2026-10-17: "I don't think ops review is relevant here. This is an internal tool just used by me", then "Cli blast radius makes sense though."
**How to apply:** when rotating lenses for a Daedalus round, drop ops and keep CLI blast radius. Measurement correctness and privacy also apply, because the logs hold prod data. Related: [[project-daedalus]], [[review-gate-playbook]].
