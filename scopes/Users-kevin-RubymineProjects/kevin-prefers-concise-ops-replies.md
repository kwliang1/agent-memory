---
name: kevin-prefers-concise-ops-replies
description: "Kevin wants concise deliverables/artifacts (and ops replies) — facts + IDs + scripts, cut the prose"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6ee65a6a-cf9a-492e-b90d-2ed3ee68acec
  modified: 2026-08-05T20:24:52.353Z
---

Kevin wants **concise** output — this applies to remediation artifacts/deliverables especially, and to live ops-thread replies. During the Chris Camillo entity-transfer incident (2026-08-05) he said "Be more concise (in the artifact)" after I shipped a long, prose-heavy remediation log.

**Why:** he wants the signal — what happened, the IDs, the scripts — not paragraphs of explanation around each point. Long write-ups slow him down.

**How to apply:** in an artifact/remediation log, lead with the facts: tight tables of IDs, the exact scripts run, one-line-per-point root cause. Cut prose paragraphs, redundant callouts, and restated context. A skimmable reference beats a narrative essay. Same for chat replies in Discord/Slack ops threads — lead with the answer/script, drop the "here's what I'll do next" scaffolding. Still verify before asserting (fact-based-adversary style) — just say it in fewer words.

**Also PR descriptions:** a few short prose sections, 3-5 sentences each — not bullet trees, file-by-file logs, or review-round narration (2026-08-05).

**Recurred 2026-09-11 (LP porting thread), and this is the sharpest statement of it:** *"you're still being too verbose. start with the conclusion and I will probe as needed."* I had been sending multi-section memos with tables, mechanism walkthroughs and next-steps into a live Slack thread while he was making a fast decision.

**The rule for live threads: answer in 1-4 lines. Conclusion first, one line of grounded why, one question if a decision is needed. Stop.** He will ask for the mechanism, the table, or the evidence if he wants it — and he does ask. Supplying it unprompted costs him reading time at exactly the moment he is deciding. Depth belongs in an arti he can open on his own schedule, never in the thread. This also applies when the finding is genuinely important: a big finding gets a *shorter* reply, not a longer one, because it needs to be read immediately.

