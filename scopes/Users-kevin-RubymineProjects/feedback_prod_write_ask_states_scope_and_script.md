---
name: feedback_prod_write_ask_states_scope_and_script
description: "A \"reply run it\" ask for a prod write must state the blast radius in plain words and inline the script"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6c746fa6-aaf7-4551-9162-6ddf2ec4bb3f
  modified: 2026-11-06T05:48:51.330Z
---

When asking Kevin to approve a prod write ("reply 'run it'"), lead with the blast radius in plain words (N rows on M accounts, NOT just the one account we were discussing) and inline the exact script in the same message.

**Why:** 2026-11-06, BANK-2720 cleanup. The dry-run output said "selected=858 accounts=303", but the conversation had been about jared's one account. Kevin said "run it", then right after asked "was this still scoped to that one account? oh it's not — can you reverify your logic is correct, and then inline the script here". The commit was correct and reversible, but he approved without seeing the scope.

**How to apply:** the ask message has three parts: a plain-English scope line ("this deletes 858 rows on 303 accounts, not only CA 98214"), the dry-run output, and the script inline. Re-verify after the commit with an independent read-only check over the destroy versions. Related: [[feedback_money_movement_script_not_execute]], [[feedback_verify_totals_not_just_counts]].
