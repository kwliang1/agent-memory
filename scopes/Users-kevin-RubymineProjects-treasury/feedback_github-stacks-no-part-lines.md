---
name: feedback_github-stacks-no-part-lines
description: In a GitHub native stack (gh stack), don't add "Part N of M / stack: #a → #b" lines to PR bodies — the stack badge already shows it
metadata:
  type: feedback
---
Kevin wants every PR stack as a GitHub native stack (`gh stack`, needs gh ≥ 2.90), not Graphite (2026-11-03, BANK-1689 stack #9437; now in global CLAUDE.md). GitHub renders a stack badge (e.g. "3/3") with position and links on every PR in the stack.

**Why:** On PR #9312 (2026-10-29) I added "Part 3 of 3 … (stack: #9324 → #9325 → #9312). Builds on …" lines; Kevin flagged it as saying the same thing twice.

**How to apply:** For gh-stack PRs, write bodies about the layer's own change only; no position/stack lines. Branches adopted by `gh stack init` should be managed with `gh stack`, not `gt`. Related: [[gate-checklist]].

This does not override [[feedback_multi_pr_plan_in_each_pr]] (Kevin, 2026-11-06): a deploy-ordered series still carries the full numbered plan with its run gates in every PR. That is content; a bare "Part N of M" or stack-chain line is the duplicate.
