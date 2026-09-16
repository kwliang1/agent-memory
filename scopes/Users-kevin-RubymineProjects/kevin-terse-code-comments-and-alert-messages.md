---
name: kevin-terse-code-comments-and-alert-messages
description: Kevin enforces terse one-line code comments AND terse alert/monitor messages — I over-wrote multi-paragraph comments + a verbose Datadog monitor message and he called it out 3× in one PR.
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 16798c4a-4e12-46cb-9764-e852c5d6bd9c
  modified: 2026-08-19T05:35:51.640Z
---

On BANK-1829/1841 (treasury reaper + Datadog monitor) I wrote multi-paragraph file-header comments, a "Metrics:" doc block, and a long multi-section Datadog monitor `message`. Kevin flagged all of it — "why is this so long? what happened to my persisted directive to be concise?" — across three separate messages.

**Why:** global CLAUDE.md already says "Keep code comments concise — a few lines at most... Default to one short line; multi-line/paragraph comments are a smell — cut them hard." I under-applied it, and it extends beyond code comments to **Datadog monitor `message` fields** (and any alert/runbook text) — those must be terse too, not walls of prose.

**How to apply:** default every code comment to ONE line stating the non-obvious WHY; no doc blocks restating metric names the code already shows; no multi-paragraph headers. For Datadog monitors: intro line + the fire modes/triage in 1-2 tight lines + oncall handle + markers — drop restating `{{#is_alert}}` blocks unless they add real signal. Mirror the terser sibling (e.g. `outgoing-payment-stuck-requested.json`), not the verbose one (`tp-card-event-silence.json`). Complements [[kevin-prefers-concise-ops-replies]] and [[kevin-prose-plain-english]] — same instinct, applied to code+config, not just chat. Relates to [[bank-1787-pending-verification-park-resume]].
