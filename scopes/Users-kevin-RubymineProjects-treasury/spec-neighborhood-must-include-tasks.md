---
name: spec-neighborhood-must-include-tasks
description: "When a change guards a service method, hand-picked spec paths miss spec/tasks/ — maintenance-task specs build fixtures by calling the very service you just guarded"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a0e70fb3-ad7e-402e-bfde-cb08253d1620
  modified: 2026-07-27T23:32:56.127Z
---

When adding a guard/validation to a treasury service method, a hand-picked spec neighbourhood (`spec/services`, `spec/graphql`, `spec/public_api`) **is not enough** — run the full suite, or at minimum include `spec/tasks/`.

**What went wrong (2026-07-27, PR #8148):** I added a guard to `IncomingWires::StateService.return!` and reported "280 examples, 0 failures" across four hand-picked dirs. A review agent found `spec/tasks/maintenance/unreturn_incoming_wire_task_spec.rb` was **10/10 failing**. CI would have been red.

**Why it's a systematic trap, not a one-off:** maintenance-task specs *reproduce the production shape of the incident the task remediates* — so they construct fixtures by calling the exact service method, in the exact bad state, that a forward-fix guard is designed to refuse. A correct guard necessarily breaks them. Same logic applies to any remediation-task spec paired with a forward fix.

**How to apply:**
- Guard/validation on a service method → run `bundle exec rspec` in full (treasury worktree: ~12 min, 7,949 examples). Cheap relative to a red CI + force-push cycle.
- Before claiming green, say *which paths* ran. "0 failures" over a subset is true and misleading at once.
- Fixing such a fixture: prefer reordering (e.g. attach the linkage *after* the guarded call) over `allow(...).to receive` stubs — keeps the real code path. Check whether the spec's factory program/state even trips the guard first.
- Triage full-suite failures by rebasing onto current main first: most "failures" are a stale base. Prove the survivors pre-existing by checking out `origin/main` in the worktree and running them there.

Related: [[treasury-worktree-dev-loop]], [[shared-checkout-worktree-isolation]].
