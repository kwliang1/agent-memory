---
name: feedback-arti-is-default-artifact-tool
description: "Kevin's default artifact tool is arti (mcp__arti__add_artifact) — write designs/docs there, not to local markdown or chat"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: af366db7-dedb-49ab-a556-1a80afef428d
  modified: 2026-09-18T21:04:37.555Z
---

Publish written deliverables (designs, RCAs, retros, review write-ups) to **arti** via
`mcp__arti__add_artifact`, then link the arti URL in chat. Stated 2026-09-18: *"put the design
in an arti artifact. this should be my default artifact tool btw"*.

**Why:** arti is the internal artifact store the rest of the org reads (Linear issues link to
`arti.internal.angellist.com/s/<slug>` already). A design pasted into chat or dropped in a local
`.md` is unlinkable and unversioned.

**How to apply:** default to arti whenever the output is a document rather than an answer. Use a
stable `named_slug` so re-publishing versions the same doc instead of forking it. Keep the chat
reply short — conclusion plus the link, per [[feedback_claude_desktop]] and the writing rules.
Short answers still belong in chat; this is about documents.
