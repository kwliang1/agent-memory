---
name: feedback_console_repair_over_task_with_papertrail
description: For a one-off prod data repair, Kevin may prefer a console script over a maintenance task PR, and wants update! (PaperTrail) instead of update_all.
metadata:
  type: feedback
---

On 2026-10-20 Kevin closed a maintenance-task PR for an account-merge repair and ran it as a console paste instead, asking "can we avoid update_all? I want to leave a papertrail".

**Why:** a console run removes CI and deploy from a deadline path, and `update!` writes a ModelVersion. That version records whodunnit (the SSO role) and the console note. `update_all` writes nothing.

**How to apply:**
- For a small one-off repair under a deadline, offer the console route up front, alongside or instead of a task PR.
- Write the console script with row locks, guards that raise before any write, and `update!`.
- Validate first, read-only, with `assign_attributes` + `valid?`.
- Open with `oc('<note>')`. A prod console refuses saves without a note, and an existing session note will otherwise be used.
- Kevin runs the writes himself.

Related: [[treasury-repair-task-gotchas]], [[account-merge-strands-inflight-ach-pulls]].
