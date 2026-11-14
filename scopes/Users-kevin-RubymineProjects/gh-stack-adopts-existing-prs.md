---
name: gh-stack-adopts-existing-prs
description: Converting two existing branches with open PRs into a native GitHub stack with gh stack init + submit --auto; what each step does and does not touch
metadata:
  type: reference
---

`gh stack init <bottom> <top>` run from the top branch's worktree adopts existing branches locally and pushes nothing (treasury, 2026-11-03: #9440 under #9176). `gh stack submit --auto` then pushes every branch atomically, leaves an up-to-date PR alone, PATCHes the upper PR's base to the lower branch, and creates the stack (#9442). It did not rewrite PR titles or bodies. Run submit only after the gate: it pushes whatever the branches hold. Kevin wants native gh stacks, not Graphite, for anything stacked (CLAUDE.md Git Workflow).

**How to apply:** rebase the top branch onto the bottom locally first, gate both, then init + submit; verify with `gh stack view --short` and the upper PR's `.base.ref`.
