---
name: review-gate-five-reviewers
description: Kevin raised the pre-push review gate from 3 to 5 parallel reviewers per round (2026-07-08)
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c16ecbd5-02ed-4ad1-b438-6ef8a0711896
---

Kevin instructed (2026-07-08, BANK-1585 session): use **5 parallel reviewers per round** in the pre-push review gate, up from the 2-3 in his CLAUDE.md review-loop-performance notes.

**Why:** more lens diversity per round; the MMF/ledger domain kept surfacing real findings (fee-floor hole, prod data audit) that single-lens rounds could miss.

**How to apply:** each gate round spawns 5 independent agents with distinct lenses (e.g. ledger-invariants, concurrency/state-machine, security/money-movement, spec-soundness/CI-shape, domain/product semantics). Full diff inline, read budget capped, frontier model. Clean-round counting rules unchanged (2 successive clean rounds, explicit "no concerns"). See [[review-gate-catches]].
