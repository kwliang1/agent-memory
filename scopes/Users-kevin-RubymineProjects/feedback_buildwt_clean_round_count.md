---
name: feedback_buildwt_clean_round_count
description: "In build-wt spawns, the number Kevin passes is the required count of SUCCESSIVE CLEAN review rounds, not a round ceiling"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e9be6599-0ba2-4555-b5f8-9952c11f69ba
  modified: 2026-08-19T22:28:46.457Z
---

In a build-wt spawn prompt like `build-wt: nova 3 execute NOVA-XXXX`, the number (`3`) is the count of **successive clean review-agent rounds required before pushing** — NOT a ceiling on how many review rounds you may run.

**Why:** Kevin corrected this explicitly on NOVA-3787 (2026-08-19): "that 3 was supposed to specify the number of successive clean review rounds, not a review round ceiling."

**How to apply:** Run review rounds until you get N successive fully-clean rounds (all lenses/agents "no concerns"). Any round with an addressable finding resets the counter to 0 — fix, then keep going. Do not stop at N total rounds. See the pre-push review gate in [[../feedback...]] / user CLAUDE.md. Also: hard "never use `let`" rule — use a `const` holder object for mutable test state.
