---
name: check-review-findings-for-prior-gated-branch
description: Before implementing a treasury ticket, grep ~/.claude/review-findings/treasury/ for earlier gated branches of the same work; handoffs can omit them
metadata:
  type: feedback
---

BANK-2429 (Rails 8.1 bump, 2026-10-27): the handoff said "start from main", but an equivalent branch (`kevinliang/bank-1845`, treasury-pine worktree) had already passed a 5-round gate and was never pushed. I found it only after resolving the lock differently (rack 3 instead of `--conservative` rack 2.2) and writing a weaker spec.

**Why:** prior gate outcomes, recipes and decisions live in `~/.claude/review-findings/treasury/<branch>/` (HANDOFF.md, outcomes-r*.md), not in Linear or the handoff.

**How to apply:** at the start of a ticket, `ls ~/.claude/review-findings/treasury/ | grep -i <issue or parent issue>` and `git branch -a | grep <parent>`. Read any HANDOFF.md/outcomes there before choosing an approach.

Related trap from the same PR: piping input to `rails console` makes pry echo it, so `grep sentinel` false-passes. Compute the sentinel (`"a_" + "b"`) and also fail on `^Error loading` (pry swallows .pryrc errors). See [[srb-tc-is-not-the-sorbet-ci-step]].
