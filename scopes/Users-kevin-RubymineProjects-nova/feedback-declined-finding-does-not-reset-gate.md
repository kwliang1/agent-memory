---
name: feedback-declined-finding-does-not-reset-gate
description: "In the pre-push gate, a round whose only feedback you decline with reasoning counts as clean, even if the finding is new that round"
metadata:
  node_type: memory
  type: feedback
  originSessionId: d08ac72a-6c6d-4e6e-9dcd-230b42d28b7d
  modified: 2026-10-01T17:22:25.109Z
---

A finding declined with reasoning never resets the gate's clean-round counter, whether it was declined in an earlier round or is brand new this round. The counter resets only on feedback you actually act on.

**Why:** On #10607 (2026-10-01) I treated a newly declined comment-density finding as a reset and started an extra round. Kevin: "no it shouldn't reset the count if you decline it."

**How to apply:** A round with zero findings, or only declined ones, counts as clean. Two in a row means push. If an extra round is already running when you realise this, stop it. Related: [[feedback-two-reviewers-per-round]]
