---
name: feedback_verify_totals_not_just_counts
description: "Don't call a data method 'verified' after matching row counts; Kevin's first question was 'Did you verify the new total?' Reconcile the headline number line by line before reporting."
metadata:
  node_type: memory
  type: feedback
  originSessionId: d9e5eaea-6715-4c6a-ab71-f47fc5871200
  modified: 2026-10-15T19:49:34.246Z
---

When reproducing a historical data pull, verifying that the vehicle/row sets match is not verification of the number. Kevin's first reply after I reported a "verified" bucket CTE for the scout stats was "Did you verify the new total?" and the honest answer was no: I had matched investment counts per bucket but not a single dollar line.

**Why:** the headline is the dollar figure. Counts can match while amounts are wrong (Galaxy summed INR as USD and read $131.9M instead of $16M; Spearhead paid-in had moved $21M because flags were backfilled). Those only surface when every line of the total is reconciled.

**How to apply:** before saying "verified" or "matches", reconcile each line of the reported total against the source, note which lines are exact, which match after FX/measure differences, and which are open. Put that table in the deliverable. If only counts were checked, say "counts match; dollars not yet reconciled".

Related: [[feedback_verify_new_assertions_can_fail]], [[project_scout_fund_stats_skill]].
