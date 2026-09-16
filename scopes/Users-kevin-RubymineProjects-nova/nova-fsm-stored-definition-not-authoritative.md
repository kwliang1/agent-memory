---
name: nova-fsm-stored-definition-not-authoritative
description: "nova FSM engine never reads fsm_workflow.definition/canonicalHash back — transitions run off the in-process graph, so registerGraph last-write-wins is safe and intended."
metadata: 
  node_type: memory
  type: reference
  originSessionId: ca52b8bd-f630-4b73-90ca-325c3713527d
  modified: 2026-09-15T13:36:30.523Z
---

Nothing in the nova FSM engine reads the stored graph definition back. Transitions execute
against the in-process graph each process registered at boot, so a `canonicalHash` disagreement
between two processes changes **what is recorded, not what executes**.

Harshaneel (FSM owner) on nova#10125, 2026-09-15: "Last-write-wins is the semantic I want.
Revisit only if that column ever becomes authoritative."

Why it matters: it is what makes `registerGraph` reconciling a lost insert race (rescue P2002,
re-read, reconcile) safe rather than a data-integrity risk — the losing boot adopting the
winner's row cannot change behaviour. Any future change that makes `fsm_workflow.definition`
authoritative invalidates this and the reconcile needs revisiting.

Related: [[nova-3788-service-core]].
