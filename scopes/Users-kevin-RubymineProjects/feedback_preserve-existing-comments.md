---
name: preserve-existing-comments
description: Do not delete pre-existing comments when refactoring — only change code you were asked to change
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b371b971-f30f-4b8b-b6ac-64c11c66388f
---

Do not strip pre-existing comments from code when refactoring or adding features. Only modify the code you were asked to change — removing existing comments is unnecessary scope creep.

**Why:** Kevin flagged this when I deleted helping comments from `outer_join` and `pretty_print` while adding IVC-wide comparison. The comments explained the matching algorithm and sign convention, which are non-obvious for oncall engineers reading the code.

**How to apply:** When editing a method, preserve all existing comments unless they're factually wrong after your changes. If a comment needs updating to reflect new behavior, update it — don't delete it.
