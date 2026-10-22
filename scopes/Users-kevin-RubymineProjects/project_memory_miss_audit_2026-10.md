---
name: project-memory-miss-audit-2026-10
description: 30-day audit (9/12–10/12) of corrections vs memory — ~10 misses, half cross-scope; MEMORY.md 200-line truncation; Rule Cards design: recommended against, Kevin undecided
metadata:
  node_type: memory
  type: project
  originSessionId: 6663ce30-f077-455a-a484-71086312cc7c
  modified: 2026-10-13T06:10:13.687Z
---

Audit run 2026-10-12 in the harness-philosophy thread. 3,190 Kevin bridge messages → 330 keyword-filtered candidates → agent-classified.

- 31 reusable-rule corrections: 10 recall misses, 6 compliance misses, 15 new rules.
- Recall misses (after adversarial check): 5/10 cross-scope (umbrella sessions doing treasury/hydra work never load that scope; worktrees get the parent repo index but NOT the umbrella one, memory-scope.sh:57-63); 2/10 had the rule spelled out in the loaded index line and ignored it (really compliance); only 1/10 was "label hid the rule". ~1/10 identifier-shaped.
- Claude Code truncates MEMORY.md at 200 lines / 25KB; nova 160 lines/20KB, umbrella 155 lines on 10/12 — near the cliff.
- Compliance misses (rule loaded, broken anyway) all fell on 9/15–9/18 — comment length, PR-body size. None after.
- Caveats: keyword prefilter under-counts; classification by agents, med confidence.

**Why:** Kevin asked whether to restructure memory (wiki vs atomic vs graph). Data says storage shape isn't the problem and the miss rate is small.
**How to apply:** a 'Rule Cards' design (pending queue, nightly sweep, digest) was drafted 10/12 and I recommended against it (Kevin undecided) — over-control for ~5 fixable misses/month. Minimal moves offered: give worktrees the umbrella index too; prune indexes back from the 200-line cliff. Raw data: session scratchpad out_0*.jsonl (ephemeral). Related: [[review-gate-playbook]].
