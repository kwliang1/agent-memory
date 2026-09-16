---
name: ai-feedback-before-review-gates
description: "Workflow order — address PR AI-bot feedback (Cursor Bugbot, Devin) before running the pre-push review-agent gate"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cc2cfd62-e6a4-42d7-8933-ac0a05308ad1
---

When iterating on a PR, the order is: make the change → **address/incorporate the PR's AI-bot feedback (Cursor Bugbot, Devin Review) first** → *then* run the pre-push review-agent gate → push.

**Why:** Kevin asked for this explicitly (2026-06-13). The AI bots re-review on every push and surface concrete bugs (invariant violations, NoMethodErrors, stale-cache, etc.); folding their valid findings in *before* spawning the independent review agents means the gate reviews the already-corrected code, so the two review layers compound instead of the gate blessing code the bots will then flag.

**How to apply:**
- After pushing, fetch bot comments on each PR: `gh api repos/angellist/venture/pulls/NUMBER/comments` and filter `.user.login` for `cursor`/`devin`/`copilot`/`bot`. Issue-level comments via `.../issues/NUMBER/comments`.
- Each Cursor comment ends with "Reviewed by Cursor Bugbot for commit SHA" — check that SHA against the current branch HEAD to tell live findings from stale ones (findings on superseded commits are often already fixed).
- Triage: fix genuinely-valid findings; explicitly dismiss false-positives / already-fixed / deliberate-decisions (e.g. a reviewer-requested removal) with reasoning rather than silently ignoring.
- Only after AI feedback is incorporated, run the standing pre-push review-agent loop (see global CLAUDE.md), then push.

Related: [[local-dev-mocking]] (the demo-hack dance during these branch hops), [[feedback_skip_local_linting]].
