---
name: review-gate-five-reviewers
description: "Pre-push review gate reviewer count: 3 per round as of 2026-09-25 (was raised 3→5 on 2026-07-08, now reverted to 3)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: c16ecbd5-02ed-4ad1-b438-6ef8a0711896
  modified: 2026-09-25T21:47:54.424Z
---

**Current instruction (2026-09-25, venture VENTURE-VK4 session): 3 parallel reviewers per round.**
Kevin asked mid-gate, "can we have 3 concurrent reviewers instead of 5?" Applies from the next round
onward — a round already in flight is allowed to finish rather than discarding paid-for work.

History: he had raised it 3→5 on 2026-07-08 (BANK-1585) for lens diversity on MMF/ledger work, where
single-lens rounds missed the fee-floor hole and the prod data audit. That reason still holds for
money-movement diffs; the 3 cap is the new default, not a claim the 5-lens rationale was wrong.

**How to apply:** pick the 3 lenses the diff actually invites. For an auth/2FA change that was
domain correctness, security, and test/CI shape. Engineering quality is not lost by dropping to 3 —
CLAUDE.md already makes *every* reviewer load `dry-kiss-review`, so the duplication-and-simplicity
pass still runs once per reviewer.

Unchanged: read-only lenses, full diff inline, frontier model at high effort, and the termination
rule — 2 successive clean rounds, "no concerns" stated explicitly, a round whose only feedback is an
already-declined finding counts as clean. See [[feedback_review-gate-catches]] and
[[feedback_review_gate_count]].

**CLAUDE.md now agrees (2026-09-25).** Kevin asked for the change directly and I applied it to
`/Users/kevin/agent-memory/config/CLAUDE.md` (which `~/.claude/CLAUDE.md` symlinks to — the symlink
itself refuses writes, edit the target). Both references updated: the gate step now reads "Spawn 3
independent reviewers per round ... pick the three the diff actually calls for from: <the five
lenses>", and the performance rule reads "The 3 reviewers of a round run in parallel". The five
lenses were kept as a selection pool rather than deleted, so coverage is chosen per diff instead of
two lenses being permanently lost. `agent-memory` is a git repo and the change is uncommitted.
