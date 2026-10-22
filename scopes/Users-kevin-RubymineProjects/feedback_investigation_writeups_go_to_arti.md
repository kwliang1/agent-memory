---
name: feedback_investigation_writeups_go_to_arti
description: "Kevin expects any investigation / alert write-up to be published as an arti artifact and linked, not attached as a file to the Slack reply"
metadata:
  type: feedback
  originSessionId: 0a3d64f9-9650-4b3a-9e62-a61713443e98
  modified: 2026-10-13
---

When a Slack-bridge investigation produces a write-up (monitor triage, incident analysis, per-record table), publish it to arti (`mcp__arti__add_artifact`, `text/markdown; charset=utf-8`, a dated `named_slug`) and put the link in the reply. Do not attach the .md via the reply tool's `files` param.

**Why:** 2026-10-13, after the SAR PendingVerification monitor triage, Kevin's only follow-up was "why didn't you create an arti for this?" — the attachment was the wrong surface; arti is where he reads and shares findings.

**How to apply:** finish the file in the scratchpad, `add_artifact` it (small markdown fits one call; >40 KB needs [[arti-chunked-upload-large-html]]), then reply 1-4 lines + the arti URL. HTML needs [[arti-html-needs-charset-meta]].
