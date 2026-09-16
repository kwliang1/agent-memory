---
name: minimal-change-in-review-gate
description: "In a review gate, fix only what the finding requires — reaching further introduced 4 regressions in one session"
metadata:
  type: feedback
---

During the BANK-1793 gate (8 rounds), **five findings were bugs I introduced, four of them while fixing an earlier round's finding**:

- Converted a scoped `if` into an early `return` "for readability" — silently swallowed an unrelated external-ACH setup call below it.
- Gated a raise on `opened_at.nil?` on a wrong mental model of the fall-through — turned a safe raise into a silent full-balance wire.
- Added a frontend status tag that read a field its own GraphQL fragment didn't select (red CI), and that mislabelled by-design-dormant routing accounts as needing operator action.
- Twice reordered a query for a sound local reason; both reverted because they changed behaviour for callers unrelated to the feature.

**Why:** each was me solving a slightly bigger problem than the finding named. A reviewer's finding defines the blast radius of the fix; going past it means shipping an unreviewed change inside a reviewed one.

**How to apply:** fix exactly what the finding states. If a neighbouring improvement is tempting, note it for the PR body or a follow-up rather than folding it in. When a fix touches a shared money path or a query's row selection, prefer reverting to main's exact behaviour over "improving" it. Re-bundle the diff each round — a stale bundle nearly produced a false critical. See [[review-gate-five-reviewers]], [[review-gate-catches]].
