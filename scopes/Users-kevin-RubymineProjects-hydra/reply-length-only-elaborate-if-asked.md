---
name: reply-length-only-elaborate-if-asked
description: "Kevin's standing rule: answer short, only elaborate when he asks"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d9380142-3df6-4689-9e54-52d39643be52
  modified: 2026-09-14T19:00:13.025Z
---

Said 2026-09-14, verbatim: **"only elaborate if I ask for it."** Immediately after telling me PR descriptions were still too verbose despite the `design-doc-voice` skill.

**Why:** he reads every line and will re-ask for depth. A long reply costs him time and gets rewritten or skipped; a short one that's missing something costs one follow-up question. The asymmetry favors short every time.

**How to apply:** default to the answer and the evidence for it — nothing else. No preamble, no inventory of what I checked, no caveats he didn't ask about, no "here's what I'd do next." Tables and multi-section replies only for something genuinely structured, like a mutation table or a verdict list he asked for. When I think context matters, offer it in one clause and let him pull: "there's a wrinkle with X if you want it."

Same failure showed up in the [[hydra-attachment-followups]] PR body — 642 words for a two-line diff. The `design-doc-voice` skill now carries a hard ~200-word PR budget with "cut a section, don't trim adjectives," added at his request, because "be concise" alone didn't change my behavior.
