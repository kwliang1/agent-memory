---
name: terse-inline-comments
description: "Kevin wants inline code comments TERSE — one short line, rationale goes in the PR/commit, not the source. Got called out for a 40-line maintenance-task header."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 173e7844-4435-4a58-b777-8e386e5f7db2
---

On BANK-1604 (2026-07-10) Kevin: "these inline comments are out of control" / "be more concise" about a ~40-line top-of-file comment block on a maintenance task.

**Why:** reinforces the CLAUDE.md rule ("multi-line/paragraph comments are a smell — cut them hard; default to one short line; put lengthy rationale in the PR description/commit"). I keep over-writing maintenance-task headers with full backstory.

**How to apply:** maintenance-task header = 3-6 tight lines max (what it does + the one non-obvious WHY + "run once via UI"). Method comments = one line. Put the full backstory/idempotency reasoning/timeline in the PR description, which already carries it. This applies to chat replies too — Kevin wants concision there as well. See [[preserve-existing-comments]].