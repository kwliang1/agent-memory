---
name: feedback_external_writing_style
description: "Kevin's house voice for all external-facing writing (PRs, Linear, artifacts, code comments, review replies)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b3595ab6-e83d-4c27-9b30-23fa6f1d5aae
  modified: 2026-08-21T15:45:12.379Z
---

Apply Kevin's plain house voice to ALL external-facing speech **on the first draft** — PR titles/descriptions, Linear issues/comments, artifacts, inline code comments, and PR review replies. This is the `design-doc-voice` skill's style; load/apply it by default, don't wait to be asked.

The `design-doc-voice` skill (`~/.claude/skills/design-doc-voice/SKILL.md`) is now the SINGLE home for this voice — broadened 2026-08-21 to a five-surface map (PR title, PR desc, Linear, artifact/doc prose, code comment [terse-why carve-out], review reply) with Kevin's own before/afters. Prefer it over restating rules here.

Scope: this is about **external-facing written deliverables only**. It is **distinct from the "russel persona"** (a separate voice context) — do not conflate them.

Concretely:
- **Concise + plain + low-jargon.** Lead with what it does / why it matters, not how it's built. Short sentences. Say the most with the fewest words.
- **PR descriptions carry the rationale** (decisions, tradeoffs, benchmarks) — not code comments or the chat.
- **Inline code comments stay light** — one terse line on the non-obvious *why*; multi-line paragraph comments are a smell (this is also in his global CLAUDE.md).
- **Draft lean; let Kevin ask for more.** Do NOT produce a maximalist draft for him to pare down — his repeated corrections this session were all "too dense / too heavy / trim it."

**Why:** across NOVA-3883 he had to repeatedly send back my first drafts as too dense (PR desc) and over-commented. He expects this style already loaded as context.

**How to apply:** before sending any external-facing text, run it through the plain-voice pass (or the `design-doc-voice` skill) and trim — present the pared version first. See [[feedback_reduce_revision_churn]].
