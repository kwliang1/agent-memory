---
name: linear-pr-url-in-description-attaches-pr
description: "Pasting a GitHub PR URL into a Linear issue description auto-attaches that PR, which can close the issue when the PR merges"
metadata:
  node_type: memory
  type: reference
  originSessionId: 593c41af-c81b-4a19-adb5-e9a0df0bcbcd
  modified: 2026-10-20T19:42:56.047Z
---

A `save_issue` description containing a GitHub PR URL (e.g. `[#9196](https://github.com/.../pull/9196)`) makes Linear convert it to a `<pull-request>` mention AND add the PR to the issue's attachments. A follow-up issue deliberately kept unlinked (BANK-2343, 2026-10-20) got #9196 attached this way.

**How to apply:** in a follow-up issue that must not close with the parent PR, reference the PR by branch name or plain text, never its URL. After any Linear write, check `attachments` in the response; remove a stray one with `delete_attachment`.
