---
name: feedback-plain-english-no-ai-prose
description: "Kevin wants plain, concise, human English in written deliverables — cut the AI-prose tells."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4205e2d5-87e0-40f2-bb11-29c76765bba7
  modified: 2026-07-31T06:36:52.223Z
---

Kevin reacted to a Linear project I wrote: "so much blatant AI prose - can you just use plain english lol... be even more concise."

**Why:** the writing read as machine-generated and bloated.

**How to apply:** write like a busy engineer typed it quickly. Cut the AI-prose tells: em-dash pile-ups, parallel triads ("event-driven, lossless, and reliable"), bolding every term, fancy filler ("load-bearing", "seam", "aspirational", "honest verdict", "not greenfield", "trip over"), and hedgy meta-commentary. Prefer short sentences, periods over em-dashes, minimal bold (labels only), concrete plain words. Shorter is better. Applies to Linear/docs AND chat replies. See [[feedback-concise-recommendations]].

Also: Linear `save_project`/`save_issue` `lead`/`assignee` fields fuzzy-match — passing the string `"null"` matched a real user (Cameron Austgen) instead of clearing. To remove, pass actual JSON `null`, not the string.
