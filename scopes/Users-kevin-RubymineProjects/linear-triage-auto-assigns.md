---
name: linear-triage-auto-assigns
description: Creating a Nova Foundations issue in Triage auto-assigns it to the triage-rotation person; Kevin wants his own issues assigned to him
metadata:
  type: feedback
---

`save_issue` with `state: Triage` on Nova Foundations (BANK) and no assignee gets auto-assigned by Linear's triage responsibility (2026-10-21, an issue landed on the person on triage rotation). Kevin: "don't assign it to erica, assign to me".

**Why:** issues Kevin asks me to create are his to route; the triage rotation shouldn't pick them up.

**How to apply:** always pass `assignee: "me"` when creating a Linear issue for Kevin, including in a Triage state, unless he names someone else.
