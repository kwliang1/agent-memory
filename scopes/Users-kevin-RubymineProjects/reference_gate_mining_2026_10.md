---
name: reference_gate_mining_2026_10
description: Baseline numbers and scripts from mining 30 days of review gates (Sep 8 – Oct 8 2026) — rerun to measure whether the gate changes worked
metadata:
  type: reference
---

Scripts are in `~/agent-memory/scripts/gate-mining/`. `extract.py` turns subagent transcripts into
`agents.json`. `attrib.py` splits cost into reviewer, main-in-gate and context tax. `brief.md` is
the reset-classification brief for analyst agents. Run them with `/usr/bin/python3`, because the
asdf python shim fails outside a versioned directory.

**Baseline, 30 days to 2026-10-08:**
- 3,070 subagents across 132 gate sessions.
- 50 gates ran 7 or more rounds; the longest was 38.
- About 520 resets classified: original bug 153, fix regression 135, test gap 99, wording 93, other 45.
- About 12 real bugs escaped long gates and were caught by Cursor, Bugbot, depthfirst, CI or a human.
- Reviewer duration: Opus 5 median 558s, Opus 5.5 median 108s. Round wall time is about 210s,
  roughly 2× the median reviewer, so the slowest reviewer sets the pace.
- On Opus 5.5, an inline diff or a `git diff` instruction ran in about 80s with 11 tools; a `.diff`
  file path ran in about 120s with 19 tools. Only 64 of 3,022 prompts put the diff inline.
- 48 reviewers died on infrastructure: 25 hit the spend limit, 20 got ENOTFOUND, 3 were not logged in.
- Cost split and the handoff comparison are in [[feedback_gate_in_fresh_session]].

**Late real bugs came from new lenses**, not from repeating the same ones: product, whole-artifact
coherence, attack-the-inputs, ops added at R10, and fresh agents after reused ones went clean.
Keep rotating lenses.

Related: [[feedback_gate_verify_fix_before_next_round]], [[feedback_gate_round1_mutation_sweep]],
[[feedback_gate_declines_need_evidence]].
