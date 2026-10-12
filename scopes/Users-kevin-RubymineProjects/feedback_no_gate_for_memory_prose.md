---
name: feedback-no-gate-for-memory-prose
description: Kevin waived the pre-push review gate for agent-memory prose-only PRs (concept Judgment entries)
metadata:
  type: feedback
---
Prose-only agent-memory PRs (e.g. filling `## Judgment` in concept files) don't need the pre-push review gate.

**Why:** 2026-10-12, on agent-memory#12, after three gate rounds whose findings were mostly overstatement nits from earlier fixes, Kevin said: "This doesn't need a review gate".

**How to apply:** For agent-memory changes that only touch prose, verify the citations mechanically and push. Code changes (bin/, hooks/) still go through the gate. Related: [[review-gate-playbook]].
