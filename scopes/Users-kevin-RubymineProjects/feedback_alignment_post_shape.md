---
name: feedback-alignment-post-shape
description: How Kevin reshapes a cross-team alignment post for Slack — bold title, labelled sections, action plan, cc the compliance lens, no hedges or closing question
metadata:
  type: feedback
---

Kevin's final #nova-eng post on money-movement authorization (2026-10-16, C09MU7S0RA4/p1792193496239319) kept my links and
numbers verbatim but reshaped the prose into: bold title → *Proposed stance* (bullets, one per owner) → *Today* (bullets) →
*PRs* (numbered) → *Action plan* (numbered). He cut the "that check is a proxy for…" argument sentence, the "we should confirm
recipient scoping" hedge, and the closing "objections?" question. He added a cc for the compliance/auditability lens with a
one-line reason, and an action item to persist the agreed stance as markdown in each repo for LLM context.

**Why:** an alignment post is scanned, not read; labelled sections let each team find its part. Hedges and open questions
weaken a stance he wants ratified; the ask is implicit in "Proposed stance".

**How to apply:** for a channel post seeking alignment, draft in that section shape from the start, state the stance
without hedging, end with a numbered action plan (including "write the decision down in the repo"), and suggest which
non-eng lens to cc. Keep prose paragraphs for threads, not for channel-level proposals. See [[feedback-concise-recommendations]]
and [[feedback-external-writing-style]].
